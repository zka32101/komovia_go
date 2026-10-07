import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';

final _logger = Logger();

/// Singleton instance of PurchaseService
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

/// Store listing (localized price/currency) for a plan; null when the store
/// can't be reached or the product isn't configured yet.
final subscriptionProductProvider =
    FutureProvider.family<ProductDetails?, SubscriptionPlan>((ref, plan) {
  return ref.watch(purchaseServiceProvider).fetchProduct(plan.productId);
});

/// Persists a successful purchase's entitlement to Firestore and refreshes
/// the cached/watched current user. Shared between the interactive purchase
/// flow below and [purchaseRecoveryProvider], since a purchase can also
/// need to be applied outside of any interactive flow (see there).
Future<void> _grantEntitlement({
  required Ref ref,
  required AuthService authService,
  required FirestoreService firestoreService,
  required SubscriptionPlan plan,
  bool skipIfAlreadyActive = false,
}) async {
  final uid = authService.currentUser?.uid;
  if (uid == null) return;

  // Re-fetch the authoritative Firestore record rather than trusting
  // authService.currentUser here: that getter can still return a
  // fabricated fallback (tutorialCompleted/gamesPlayedCount reset to
  // false/0) in the brief window before the auth stream's first
  // event lands, and saveUser's merge-set would otherwise overwrite
  // those real fields with the fallback's zeroed-out ones.
  final now = DateTime.now();
  final freshUser = await firestoreService.getUser(uid) ?? authService.currentUser!;

  // purchaseRecoveryProvider re-plays *every* unacknowledged/redelivered
  // transaction on every app launch (see its own doc comment), with no
  // server-side receipt verification to tell a genuine renewal apart from
  // the store simply re-delivering an old purchase. Without this guard, a
  // still-active subscriber's expiry would get pushed out from "now" on
  // every such replay instead of just once at actual purchase/renewal
  // time. This only protects an already-active entitlement; it can't
  // detect a stale purchase being replayed against an *expired* one
  // (that needs real receipt verification, which this app doesn't have).
  if (skipIfAlreadyActive &&
      freshUser.subscriptionActive &&
      freshUser.subscriptionEndDate != null &&
      freshUser.subscriptionEndDate!.isAfter(now)) {
    _logger.i(
      'Skipping entitlement re-grant for $uid: already active until ${freshUser.subscriptionEndDate}',
    );
    return;
  }

  final updated = freshUser.copyWith(
    subscriptionActive: true,
    subscriptionStartDate: now,
    subscriptionEndDate: now.add(plan.entitlementLength),
    updatedAt: now,
  );
  await firestoreService.saveUser(updated);
  authService.refreshCachedUser(updated);
  ref.invalidate(currentUserProvider);
}

/// Listens for purchases for as long as the app is running, independent of
/// any interactive purchase flow. `InAppPurchase.purchaseStream` redelivers
/// any transaction that was never acknowledged via `completePurchase` on
/// every future app launch — without a listener that is always active, a
/// purchase whose Firestore write failed (e.g. a network hiccup right
/// after the store charged the user) would show "purchase failed" to the
/// user while the store still considers it completed, and since nothing
/// would ever call completePurchase, the user could never recover the
/// entitlement they paid for without contacting support.
///
/// Watch this once near the app root (see GoEnApp) so it starts as soon as
/// the app launches, not only while PaywallScreen happens to be open.
final purchaseRecoveryProvider = Provider<void>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final firestoreService = FirestoreService();

  final subscription = purchaseService.purchaseStream.listen((purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          SubscriptionPlan? plan;
          try {
            plan = SubscriptionPlan.values
                .firstWhere((p) => p.productId == purchase.productID);
          } catch (_) {
            plan = null;
          }
          if (plan == null) {
            _logger.w('Unknown product in purchaseStream: ${purchase.productID}');
            break;
          }
          try {
            await _grantEntitlement(
              ref: ref,
              authService: authService,
              firestoreService: firestoreService,
              plan: plan,
              skipIfAlreadyActive: true,
            );
            await purchaseService.completePurchase(purchase);
            _logger.i('✅ Purchase recovered/synced: ${purchase.productID}');
          } catch (e) {
            // Don't complete the purchase — leave it unacknowledged so the
            // store redelivers it and this listener gets another chance.
            _logger.e('Failed to sync purchase ${purchase.productID}: $e');
          }
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          await purchaseService.completePurchase(purchase);
        case PurchaseStatus.pending:
          break;
      }
    }
  });

  ref.onDispose(subscription.cancel);
});

/// Buys the given subscription plan through the platform store, persists
/// the resulting subscription status to Firestore on success, and
/// refreshes AuthService's cache + currentUserProvider so the paywall gate
/// reflects it immediately.
///
/// Throws [PurchaseUnavailableException] when the store or product isn't
/// available yet (e.g. product IDs not configured in App Store
/// Connect/Play Console) rather than faking success — see the Twitch/
/// YouTube "not yet available" precedent elsewhere in the app.
final purchaseSubscriptionProvider = Provider<Future<void> Function(SubscriptionPlan plan)>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final firestoreService = FirestoreService();

  return (plan) async {
    _logger.i('Purchase initiated: ${plan.name}');

    final available = await purchaseService.isAvailable();
    if (!available) {
      throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
    }

    final product = await purchaseService.fetchProduct(plan.productId);
    if (product == null) {
      throw PurchaseUnavailableException('このプランは現在ご購入いただけません。しばらくしてから再度お試しください。');
    }

    final completer = Completer<PurchaseDetails>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = purchaseService.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != product.id || completer.isCompleted) continue;
          switch (purchase.status) {
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              completer.complete(purchase);
              break;
            case PurchaseStatus.error:
              // Acknowledge it too, or the store will keep redelivering
              // this failed transaction on every future launch.
              purchaseService.completePurchase(purchase);
              completer.completeError(purchase.error ?? Exception('Purchase failed'));
              break;
            case PurchaseStatus.canceled:
              purchaseService.completePurchase(purchase);
              completer.completeError(Exception('canceled'));
              break;
            case PurchaseStatus.pending:
              break;
          }
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    try {
      final started = await purchaseService.buy(product);
      if (!started) {
        throw Exception('Failed to start purchase flow');
      }

      final purchase = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw Exception('Purchase timed out'),
      );

      await _grantEntitlement(
        ref: ref,
        authService: authService,
        firestoreService: firestoreService,
        plan: plan,
      );

      await purchaseService.completePurchase(purchase);
      _logger.i('✅ Purchase completed: ${product.id}');
    } finally {
      await subscription.cancel();
    }
  };
});

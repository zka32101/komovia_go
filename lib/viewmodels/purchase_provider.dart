import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';
import 'package:komovia_go/models/go_skins.dart';
import 'package:komovia_go/config/avatar_frames.dart';
import 'package:komovia_go/utils/entitlement_adapter.dart';

final _logger = Logger();

/// Singleton instance of PurchaseService
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService();
});

/// Store listing (localized price/currency) for a plan; null when the store
/// can't be reached or the product isn't configured yet.
final subscriptionProductProvider =
    FutureProvider.family<ProductDetails?, SubscriptionPlan>((ref, plan) {
  final productId = plan.productId;
  if (productId == null) return Future.value(null);
  return ref.watch(purchaseServiceProvider).fetchProduct(productId);
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
  // A lifetime purchaser keeps lifetime: a late monthly/annual renewal or
  // redelivery must never overwrite the never-expiring entitlement with a
  // finite end date.
  if (plan != SubscriptionPlan.lifetime && freshUser.isLifetimePurchaser) {
    _logger.i('Skipping $plan grant for $uid: already a lifetime purchaser');
    return;
  }

  if (skipIfAlreadyActive &&
      freshUser.subscriptionActive &&
      freshUser.subscriptionEndDate != null &&
      freshUser.subscriptionEndDate!.isAfter(now)) {
    _logger.i(
      'Skipping entitlement re-grant for $uid: already active until ${freshUser.subscriptionEndDate}',
    );
    return;
  }

  final isLifetime = plan == SubscriptionPlan.lifetime;
  final updated = freshUser.copyWith(
    subscriptionActive: true,
    // A redelivered lifetime purchase keeps its original start date.
    subscriptionStartDate: isLifetime && freshUser.isLifetimePurchaser
        ? freshUser.subscriptionStartDate
        : now,
    // entitlementLength is null only for lifetime: "never expires".
    subscriptionEndDate: plan.entitlementLength == null
        ? null
        : now.add(plan.entitlementLength!),
    // Lifetime purchase also grants the lifetime-exclusive avatar frame,
    // persisted the same way sticky achievement frames are (earnedFrameIds,
    // see avatar_frame_provider.dart). Idempotent for redeliveries.
    earnedFrameIds: isLifetime &&
            !freshUser.earnedFrameIds.contains(FrameIds.lifetimeSupporter)
        ? [...freshUser.earnedFrameIds, FrameIds.lifetimeSupporter]
        : null,
    updatedAt: now,
  );
  await firestoreService.saveUser(updated);
  authService.refreshCachedUser(updated);
  ref.invalidate(currentUserProvider);
}

/// AI分析プランの権利を付与する(既存プレミアムとは独立したフィールド)。
/// [skipIfAlreadyActive]は_grantEntitlementと同じ理由(起動毎の再配信で
/// 期限が延び続けるのを防ぐ)。
Future<void> _grantAiAnalysisPlan({
  required Ref ref,
  required AuthService authService,
  required FirestoreService firestoreService,
  required AiAnalysisPlan plan,
  bool skipIfAlreadyActive = false,
}) async {
  final uid = authService.currentUser?.uid;
  if (uid == null) return;
  final now = DateTime.now();
  final freshUser = await firestoreService.getUser(uid) ?? authService.currentUser!;
  if (skipIfAlreadyActive && freshUser.hasAiAnalysisPlan(now)) return;
  final updated = freshUser.copyWith(
    aiAnalysisPlanEndDate: now.add(plan.entitlementLength),
    updatedAt: now,
  );
  await firestoreService.saveUser(updated);
  authService.refreshCachedUser(updated);
  ref.invalidate(currentUserProvider);
}

/// Records a one-time cosmetic purchase (non-consumable skin) on the
/// user's own doc. Idempotent, so redelivered/restored transactions are
/// safe to replay.
Future<void> _grantCosmetic({
  required Ref ref,
  required AuthService authService,
  required FirestoreService firestoreService,
  required String productId,
}) async {
  final uid = authService.currentUser?.uid;
  if (uid == null) return;
  final freshUser = await firestoreService.getUser(uid) ?? authService.currentUser!;
  if (freshUser.purchasedCosmeticIds.contains(productId)) return;
  final updated = freshUser.copyWith(
    purchasedCosmeticIds: [...freshUser.purchasedCosmeticIds, productId],
    updatedAt: DateTime.now(),
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
          if (kCosmeticProductIds.contains(purchase.productID)) {
            try {
              await _grantCosmetic(
                ref: ref,
                authService: authService,
                firestoreService: firestoreService,
                productId: purchase.productID,
              );
              await purchaseService.completePurchase(purchase);
            } catch (e) {
              _logger.e('Failed to sync cosmetic ${purchase.productID}: $e');
            }
            break;
          }
          final aiPlan = AiAnalysisPlan.values
              .where((p) => p.productId == purchase.productID)
              .firstOrNull;
          if (aiPlan != null) {
            try {
              await _grantAiAnalysisPlan(
                ref: ref,
                authService: authService,
                firestoreService: firestoreService,
                plan: aiPlan,
                skipIfAlreadyActive: true,
              );
              await purchaseService.completePurchase(purchase);
            } catch (e) {
              _logger.e('Failed to sync AI analysis plan: $e');
            }
            break;
          }
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

/// Triggers [PurchaseService.restorePurchases] and waits briefly to see
/// whether [purchaseRecoveryProvider]'s app-root listener actually granted
/// an entitlement as a result (it does the real Firestore write; this just
/// observes the outcome for the paywall's "restore" button). Returns
/// whether a subscription is now active, so the caller can show an honest
/// "restored" vs "nothing to restore" message instead of a generic one.
final restorePurchasesProvider = Provider<Future<bool> Function()>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return () async {
    _logger.i('Restore purchases requested');

    final available = await purchaseService.isAvailable();
    if (!available) {
      throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
    }

    await purchaseService.restorePurchases();

    // purchaseRecoveryProvider's listener (mounted at the app root, see
    // its own doc comment) handles the resulting `restored` events and
    // persists the entitlement to Firestore - give it a moment to do so
    // before checking whether anything actually came back.
    await Future<void>.delayed(const Duration(seconds: 2));

    final uid = authService.currentUser?.uid;
    if (uid == null) return false;
    final user = await FirestoreService().getUser(uid);
    final now = DateTime.now();
    return user != null &&
        user.subscriptionActive &&
        (user.isLifetimePurchaser ||
            (user.subscriptionEndDate != null &&
                user.subscriptionEndDate!.isAfter(now)));
  };
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

  return (plan) {
    final productId = plan.productId;
    if (productId == null) {
      return Future.error(
          PurchaseUnavailableException('This plan is not available.'));
    }
    return _runPurchaseFlow(
        purchaseService: purchaseService,
        productId: productId,
        grant: () => _grantEntitlement(
          ref: ref,
          authService: authService,
          firestoreService: firestoreService,
          plan: plan,
        ),
      );
  };
});

/// AI分析プラン(別売り月額)を購入する。フローは他の商品と共通。
final purchaseAiAnalysisPlanProvider =
    Provider<Future<void> Function(AiAnalysisPlan plan)>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final firestoreService = FirestoreService();

  return (plan) => _runPurchaseFlow(
        purchaseService: purchaseService,
        productId: plan.productId,
        grant: () => _grantAiAnalysisPlan(
          ref: ref,
          authService: authService,
          firestoreService: firestoreService,
          plan: plan,
        ),
      );
});

/// Buys a one-time cosmetic skin (non-consumable) through the exact same
/// query → buy → await PurchaseDetails → persist → acknowledge flow as
/// subscriptions; the result is recorded in `User.purchasedCosmeticIds`.
final purchaseCosmeticProvider = Provider<Future<void> Function(String productId)>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final firestoreService = FirestoreService();

  return (productId) => _runPurchaseFlow(
        purchaseService: purchaseService,
        productId: productId,
        grant: () => _grantCosmetic(
          ref: ref,
          authService: authService,
          firestoreService: firestoreService,
          productId: productId,
        ),
      );
});

/// Shared interactive purchase flow. Throws [PurchaseUnavailableException]
/// when the store or product isn't available yet rather than faking success.
Future<void> _runPurchaseFlow({
  required PurchaseService purchaseService,
  required String productId,
  required Future<void> Function() grant,
}) async {
  _logger.i('Purchase initiated: $productId');

  final available = await purchaseService.isAvailable();
  if (!available) {
    throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
  }

  final product = await purchaseService.fetchProduct(productId);
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

    await grant();

    await purchaseService.completePurchase(purchase);
    _logger.i('✅ Purchase completed: ${product.id}');
  } finally {
    await subscription.cancel();
  }
}

/// Store listing (localized price) for a cosmetic skin product; null when
/// the store can't be reached or the product isn't configured yet.
final cosmeticProductProvider =
    FutureProvider.family<ProductDetails?, String>((ref, productId) {
  return ref.watch(purchaseServiceProvider).fetchProduct(productId);
});

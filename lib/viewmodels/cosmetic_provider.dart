import 'package:logger/logger.dart';
import 'package:riverpod/riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/go_skins.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';

final _logger = Logger();

/// Store product ids of the cosmetic skins the current user has bought.
final purchasedCosmeticIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(currentUserProvider)?.purchasedCosmeticIds.toSet() ?? const {};
});

/// Whether the current user owns [item] (free / subscription / lifetime /
/// purchased).
final cosmeticOwnedProvider = Provider.family<bool, CosmeticItem>((ref, item) {
  return item.isOwnedBy(
    hasActiveSubscription: ref.watch(isSubscriptionActiveProvider),
    purchasedProductIds: ref.watch(purchasedCosmeticIdsProvider),
    isLifetimePurchaser: ref.watch(userEntitlementProvider).isLifetime,
  );
});

/// The board skin currently applied. Falls back to the default if nothing
/// is selected, the id is unknown, or the selection is no longer owned
/// (e.g. a subscription-included skin after the subscription lapsed).
final selectedBoardSkinProvider = Provider<GoBoardSkin>((ref) {
  final skin = boardSkinById(ref.watch(currentUserProvider)?.boardSkinId);
  return ref.watch(cosmeticOwnedProvider(skin.item)) ? skin : boardSkinById(null);
});

/// The stone set currently applied (same fallback rules as boards).
final selectedStoneSkinProvider = Provider<GoStoneSkin>((ref) {
  final skin = stoneSkinById(ref.watch(currentUserProvider)?.stoneSkinId);
  return ref.watch(cosmeticOwnedProvider(skin.item)) ? skin : stoneSkinById(null);
});

/// Persists the selected skin for its category, same pattern as
/// [updateAvatarProvider].
final selectCosmeticProvider = Provider<Future<void> Function(CosmeticItem)>((ref) {
  final firestoreService = FirestoreService();

  return (item) async {
    final authService = ref.read(authServiceProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('No user logged in');
    if (!ref.read(cosmeticOwnedProvider(item))) {
      throw StateError('Cosmetic ${item.id} is not owned');
    }
    final updated = item.category == kBoardSkinCategory
        ? user.copyWith(boardSkinId: item.id, updatedAt: DateTime.now())
        : user.copyWith(stoneSkinId: item.id, updatedAt: DateTime.now());
    await firestoreService.saveUser(updated);
    authService.refreshCachedUser(updated);
    ref.invalidate(currentUserProvider);
    _logger.i('✅ Selected cosmetic ${item.id}');
  };
});

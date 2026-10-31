import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/go_skins.dart';
import 'package:komovia_go/models/user.dart';
import 'package:komovia_go/viewmodels/index.dart';

User _user({String? board, String? stone, List<String> bought = const []}) => User(
      uid: 'u1',
      email: 'a@b.c',
      subscriptionActive: false,
      subscriptionStartDate: DateTime(2026),
      tutorialCompleted: true,
      gamesPlayedCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      boardSkinId: board,
      stoneSkinId: stone,
      purchasedCosmeticIds: bought,
    );

ProviderContainer _container(User? user, {bool sub = false}) => ProviderContainer(overrides: [
      currentUserProvider.overrideWithValue(user),
      isSubscriptionActiveProvider.overrideWithValue(sub),
    ]);

void main() {
  group('catalog', () {
    test('ids are unique and defaults are free', () {
      final ids = [...kGoBoardSkins.map((s) => s.id), ...kGoStoneSkins.map((s) => s.id)];
      expect(ids.toSet().length, ids.length);
      expect(boardSkinById(null).id, kDefaultBoardSkinId);
      expect(stoneSkinById('unknown').id, kDefaultStoneSkinId);
      expect(boardSkinById(null).item.isFreeForAll, isTrue);
      expect(stoneSkinById(null).item.isFreeForAll, isTrue);
    });

    test('each category has free, subscription and purchasable items', () {
      for (final items in [
        kGoBoardSkins.map((s) => s.item),
        kGoStoneSkins.map((s) => s.item),
      ]) {
        expect(items.where((i) => i.isFreeForAll).length, greaterThanOrEqualTo(2));
        expect(items.where((i) => i.includedWithSubscription).length, 1);
        expect(items.where((i) => i.iapProductId != null).length, 2);
      }
      expect(kCosmeticProductIds, {
        kBoardSkinStoneSlabProductId,
        kBoardSkinMinimalProductId,
        kStoneSkinGlassProductId,
        kStoneSkinJadeProductId,
      });
    });

    test('ownership resolution', () {
      final sub = boardSkinById('board_dark_kaya').item;
      final iap = boardSkinById('board_stone_slab').item;
      expect(sub.isOwnedBy(hasActiveSubscription: false, purchasedProductIds: {}), isFalse);
      expect(sub.isOwnedBy(hasActiveSubscription: true, purchasedProductIds: {}), isTrue);
      expect(iap.isOwnedBy(hasActiveSubscription: true, purchasedProductIds: {}), isFalse);
      expect(
          iap.isOwnedBy(
              hasActiveSubscription: false,
              purchasedProductIds: {kBoardSkinStoneSlabProductId}),
          isTrue);
    });
  });

  group('selection providers', () {
    test('no user / no selection falls back to defaults', () {
      final c = _container(null);
      expect(c.read(selectedBoardSkinProvider).id, kDefaultBoardSkinId);
      expect(c.read(selectedStoneSkinProvider).id, kDefaultStoneSkinId);
    });

    test('owned selection is applied', () {
      final c = _container(_user(
          board: 'board_stone_slab',
          stone: 'stone_flat',
          bought: [kBoardSkinStoneSlabProductId]));
      expect(c.read(selectedBoardSkinProvider).id, 'board_stone_slab');
      expect(c.read(selectedStoneSkinProvider).id, 'stone_flat');
    });

    test('lapsed subscription skin falls back to default', () {
      final user = _user(stone: 'stone_gold_silver');
      expect(_container(user, sub: true).read(selectedStoneSkinProvider).id, 'stone_gold_silver');
      expect(_container(user).read(selectedStoneSkinProvider).id, kDefaultStoneSkinId);
    });
  });

  test('skin selection and purchases round-trip through Firestore', () async {
    final db = FakeFirebaseFirestore();
    final user = _user(
        board: 'board_minimal', stone: 'stone_jade', bought: [kStoneSkinJadeProductId]);
    await db.collection('users').doc('u1').set(user.toFirestore());
    final read = User.fromFirestore(await db.collection('users').doc('u1').get());
    expect(read.boardSkinId, 'board_minimal');
    expect(read.stoneSkinId, 'stone_jade');
    expect(read.purchasedCosmeticIds, [kStoneSkinJadeProductId]);

    // Docs written before these fields existed still parse.
    await db.collection('users').doc('old').set({'email': 'x'});
    final old = User.fromFirestore(await db.collection('users').doc('old').get());
    expect(old.boardSkinId, isNull);
    expect(old.purchasedCosmeticIds, isEmpty);
  });
}

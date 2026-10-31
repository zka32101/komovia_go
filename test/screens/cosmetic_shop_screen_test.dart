import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/go_skins.dart';
import 'package:komovia_go/models/user.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/cosmetic_shop_screen.dart';

import '../test_utils.dart';

User _user({List<String> bought = const []}) => User(
      uid: 'u1',
      email: 'a@b.c',
      subscriptionActive: false,
      subscriptionStartDate: DateTime(2026),
      tutorialCompleted: true,
      gamesPlayedCount: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      purchasedCosmeticIds: bought,
    );

Future<void> _pump(WidgetTester tester, {bool sub = false, List<String> bought = const []}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(_user(bought: bought)),
    isSubscriptionActiveProvider.overrideWithValue(sub),
    cosmeticProductProvider.overrideWith((ref, id) async => null),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    TestUtils.buildTestableWidget(child: const CosmeticShopScreen(), container: container),
  );
  await tester.pump();
}

Finder _tile(String id) => find.byKey(ValueKey(id));

Finder _inTile(String id, Finder f) => find.descendant(of: _tile(id), matching: f);

void main() {
  testWidgets('lists every skin with defaults equipped', (tester) async {
    await _pump(tester);
    for (final s in [...kGoBoardSkins.map((e) => e.id), ...kGoStoneSkins.map((e) => e.id)]) {
      expect(_tile(s), findsOneWidget);
    }
    expect(_inTile(kDefaultBoardSkinId, find.text('使用中')), findsOneWidget);
    expect(_inTile(kDefaultStoneSkinId, find.text('使用中')), findsOneWidget);
    expect(_inTile('board_light_wood', find.text('使う')), findsOneWidget);
  });

  testWidgets('locked items show subscribe / buy actions', (tester) async {
    await _pump(tester);
    expect(_inTile('board_dark_kaya', find.byType(FilledButton)), findsOneWidget);
    expect(_inTile('board_dark_kaya', find.text('プレミアム会員で利用可')), findsWidgets);
    expect(_inTile('board_stone_slab', find.text('購入')), findsOneWidget);
    expect(_inTile('stone_glass', find.text('購入')), findsOneWidget);
  });

  testWidgets('subscription and purchases unlock items', (tester) async {
    await _pump(tester, sub: true, bought: [kStoneSkinGlassProductId]);
    expect(_inTile('board_dark_kaya', find.text('使う')), findsOneWidget);
    expect(_inTile('stone_glass', find.text('使う')), findsOneWidget);
    expect(_inTile('stone_glass', find.text('所有済み')), findsOneWidget);
    expect(_inTile('stone_jade', find.text('購入')), findsOneWidget);
  });
}

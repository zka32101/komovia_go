import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/views/screens/how_to_play_screen.dart';

import '../test_utils.dart';

void main() {
  group('HowToPlayScreen', () {
    testWidgets('renders without overflow errors', (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const HowToPlayScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '項目4: 盤の各部の名称の図を展開しても描画エラー（見切れによる'
        'オーバーフロー）が起きない', (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const HowToPlayScreen()),
      );
      await tester.pumpAndSettle();

      // 最初のセクション（盤の各部の名称）を展開する。
      await tester.tap(find.text('盤の各部の名称'));
      await tester.pumpAndSettle();

      // 図(CustomPaint)が描画され、例外(オーバーフロー等)が無いことを
      // 確認する。
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);

      // 図のキャンバスサイズ自体は変わっていない(260x260) -
      // ラベルがキャンバス内に収まるよう、描画側で内側マージンを
      // 取るようにした(見切れの修正)。
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => b.width == 260 && b.height == 260);
      expect(sizedBoxes, isNotEmpty);
    });
  });
}

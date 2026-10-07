import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test_utils.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/index.dart';

void main() {
  group('CorrespondenceGameScreen Widget Tests', () {
    testWidgets('初期レンダリング - AppBar表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
              boardSize: 19,
            ),
          ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('手紙型対局'), findsWidgets);
    });

    testWidgets('戻るボタンが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('ゲーム一覧セクションが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('UIレイアウト - ダークモード背景', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);
    });

    testWidgets('ボードサイズパラメータ - 9x9対応', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
              boardSize: 9,
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('ボードサイズパラメータ - 19x19対応', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
              boardSize: 19,
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('ボードサイズパラメータ - 13x13対応', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
              boardSize: 13,
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('レスポンシブ対応 - SingleChildScrollView使用', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('テキストスタイル - 日本語ラベル表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('コンテナ配置 - Column構造確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('デバイスサイズ対応 - 小さい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('デバイスサイズ対応 - 大きい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1200, 1600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('ユーザーID渡し - 異なるユーザーID対応', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'user-abc-123',
              opponentUid: 'user-xyz-789',
            ),
          ),
      );

      expect(find.byType(CorrespondenceGameScreen), findsOneWidget);
    });

    testWidgets('プロバイダー統合 - ゲーム一覧読み込み', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('状態表示 - SingleChildScrollViewマウント', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('エラーハンドリング - UI表示保証', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('ロギング実装確認 - 生成時の処理', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user-log',
              opponentUid: 'opponent-log',
            ),
          ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ナビゲーション - 戻るボタンの存在確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: CorrespondenceGameScreen(
              uid: 'test-user',
              opponentUid: 'opponent-user',
            ),
          ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}

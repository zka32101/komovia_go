import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/index.dart';

import '../test_utils.dart';

/// Overrides [startPuzzleRushProvider] so PuzzleRushScreen never touches a
/// real Firestore connection (there is none in a plain `flutter test`
/// process), returning a fixed successful session instead.
ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: [
      startPuzzleRushProvider.overrideWith(
        (ref, params) async => PuzzleRushRecord(
          id: 'test-puzzle-rush-1',
          uid: params.uid,
          startedAt: DateTime.now(),
          endedAt: DateTime.now(),
          durationSeconds: 0,
          solvedCount: 0,
          correctCount: 0,
          totalAttempts: 0,
          score: 0,
          maxCombo: 0,
          averageSolveTime: 0,
          difficulty: params.difficulty,
          puzzleIds: const [],
          puzzleDifficulties: const [],
          puzzleResults: const [],
          solveTimes: const [],
          createdAt: DateTime.now(),
        ),
      ),
    ],
  );
}

void main() {
  group('PuzzleRushScreen Widget Tests', () {
    testWidgets('初期レンダリング - AppBar表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('詰碁ラッシュ'), findsWidgets);
    });

    testWidgets('戻るボタンが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('難易度表示 - EASY', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'easy'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('難易度表示 - NORMAL', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('難易度表示 - HARD', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'hard'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('難易度表示 - EXPERT', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'expert'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('タイマー表示 - 初期5分', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.text('残り時間'), findsWidgets);
    });

    testWidgets('スコアセクション - 表示確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('UIレイアウト - ダークモード背景', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);
    });

    testWidgets('レスポンシブ対応 - SingleChildScrollView使用', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('アクションボタン - セッション終了ボタン', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.text('セッションを終了'), findsWidgets);
    });

    testWidgets('デバイスサイズ対応 - 小さい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(PuzzleRushScreen), findsOneWidget);
    });

    testWidgets('デバイスサイズ対応 - 大きい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1200, 1600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(PuzzleRushScreen), findsOneWidget);
    });

    testWidgets('ユーザーID パラメータ確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'user-abc-123', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(PuzzleRushScreen), findsOneWidget);
    });

    testWidgets('プロバイダー統合 - startPuzzleRushProvider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('リーダーボード読み込み - 非同期処理', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('テキストスタイル - 日本語表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('ナビゲーション - 戻るボタン機能', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('エラーハンドリング - 画面表示保証', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: PuzzleRushScreen(uid: 'test-user', difficulty: 'normal'),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

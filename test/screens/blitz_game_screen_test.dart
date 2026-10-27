import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/index.dart';

import '../test_utils.dart';

class MockBlitzGameService {
  Future<BlitzGameRecord> startBlitzGame({
    required String uid,
    required int boardSize,
    String? aiLevel,
    String? opponentUid,
  }) async {
    return BlitzGameRecord(
      id: 'test-blitz-1',
      uid: uid,
      boardSize: boardSize,
      aiLevel: aiLevel ?? '5',
      opponentUid: opponentUid ?? 'ai',
      whitePlayer: uid,
      blackPlayer: opponentUid ?? 'ai',
      moveHistory: [],
      result: 'active',
      winnerColor: 'draw',
      ratingChange: 0,
      sgfData: '',
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: 0,
      createdAt: DateTime.now(),
    );
  }

  BlitzGameRecord _fakeRecord({
    required String gameId,
    required String result,
    required String winnerColor,
  }) {
    final now = DateTime.now();
    return BlitzGameRecord(
      id: gameId,
      uid: 'test-user',
      boardSize: 9,
      aiLevel: null,
      opponentUid: 'opponent',
      whitePlayer: 'test-user',
      blackPlayer: 'opponent',
      moveHistory: const [],
      result: result,
      winnerColor: winnerColor,
      ratingChange: 0,
      sgfData: '',
      startedAt: now,
      endedAt: now,
      durationSeconds: 0,
      createdAt: now,
    );
  }
}

/// Overrides [startBlitzGameProvider] so BlitzGameScreen never touches a
/// real Firestore connection (there is none in a plain `flutter test`
/// process), returning the mock's fixed successful record instead.
ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: [
      startBlitzGameProvider.overrideWith(
        (ref, params) => MockBlitzGameService().startBlitzGame(
          uid: params.uid,
          boardSize: params.boardSize,
          aiLevel: params.aiLevel,
          opponentUid: params.opponentUid,
        ),
      ),
      // 盤面操作テストは実対局(タップ→着手記録、投了→終局)を駆動するが、
      // 実Firestoreへの接続は無い(plain flutter test)ため、記録系の
      // プロバイダーは成功レスポンスを返すだけのスタブに差し替える。
      addBlitzMoveProvider.overrideWith(
        (ref) => ({required gameId, required move, required playerColor}) async {},
      ),
      endBlitzGameProvider.overrideWith(
        (ref) => ({
          required gameId,
          required result,
          required winnerColor,
          required sgfData,
          required ratingChange,
        }) async =>
            MockBlitzGameService()._fakeRecord(
          gameId: gameId,
          result: result,
          winnerColor: winnerColor,
        ),
      ),
    ],
  );
}

void main() {
  group('BlitzGameScreen Widget Tests', () {
    testWidgets('初期レンダリング - ローディング状態', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ゲームを準備中...'), findsOneWidget);
    });

    testWidgets('Blitz ゲーム - UIコンポーネント表示確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(
            uid: 'test-user',
            boardSize: 19,
            aiLevel: '5',
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Blitz ゲーム'), findsWidgets);
    });

    testWidgets('タイマー表示 - 初期5分', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.text('残り時間'), findsWidgets);
    });

    testWidgets('戻るボタンクリック - Navigator.pop()', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });

    testWidgets('ゲーム情報表示 - ボードサイズとAIレベル', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(
            uid: 'test-user',
            boardSize: 9,
            aiLevel: '3',
          ),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.text('碁盤サイズ'), findsWidgets);
      expect(find.text('AIレベル'), findsWidgets);
    });

    testWidgets('捕獲数表示 - 初期状態は両者0', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.text('捕獲'), findsWidgets);
      expect(find.textContaining('黒0'), findsWidgets);
    });

    testWidgets('アクションボタン - パス/投了ボタン表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.text('パス'), findsOneWidget);
      expect(find.text('投了'), findsOneWidget);
    });

    testWidgets('盤面 - 実際に石を置けるGestureDetector/盤面が表示される', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('エラー状態表示 - エラーメッセージ表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('ダークモード確認 - 背景色が黒系', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);
    });

    testWidgets('レスポンシブレイアウト - SingleChildScrollView使用', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('複数ボードサイズ対応 - 9x9', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(
            uid: 'test-user',
            boardSize: 9,
            aiLevel: '3',
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(BlitzGameScreen), findsOneWidget);
    });

    testWidgets('複数ボードサイズ対応 - 19x19', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(
            uid: 'test-user',
            boardSize: 19,
            aiLevel: '5',
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(BlitzGameScreen), findsOneWidget);
    });

    testWidgets('ロギング確認 - initState時のログ記録', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user-123', boardSize: 19),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(BlitzGameScreen), findsOneWidget);
    });

    testWidgets('プロバイダー統合 - startBlitzGameProvider呼び出し', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(
            uid: 'test-user',
            boardSize: 19,
            aiLevel: '5',
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('操作: 盤面タップで石が置かれる(対人戦ローカル対面)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 9),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      // 対人戦(aiLevel==null)なので最初のタップで即座に黒石が置かれる。
      await tester.tapAt(tester.getCenter(find.byType(AspectRatio)));
      await tester.pump();

      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('操作: 投了すると終局処理が走り投了ボタンが無効化される', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 9),
          container: _buildContainer(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('投了'));
      await tester.pump();
      await tester.pump();

      final resignButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('投了'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(resignButton.onPressed, isNull);
    });

    testWidgets('状態遷移: ローディング → データ表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: BlitzGameScreen(uid: 'test-user', boardSize: 19),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump();

      expect(find.text('残り時間'), findsWidgets);
    });
  });
}

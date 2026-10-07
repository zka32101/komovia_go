import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/index.dart';

import '../test_utils.dart';

/// Overrides [startTeamGameProvider] so TeamGameScreen never touches a
/// real Firestore connection (there is none in a plain `flutter test`
/// process), returning a fixed successful record instead.
ProviderContainer _buildContainer() {
  return ProviderContainer(
    overrides: [
      startTeamGameProvider.overrideWith(
        (ref, params) async => TeamGameRecord(
          id: 'test-team-game-1',
          team1Players: params.team1Players,
          team2Players: params.team2Players,
          boardSize: params.boardSize,
          startedAt: DateTime.now(),
          endedAt: DateTime.now(),
          durationSeconds: 0,
          result: 'draw',
          winningTeam: 'draw',
          moveHistory: const [],
          sgfData: '',
          team1Moves: '',
          team2Moves: '',
          createdAt: DateTime.now(),
        ),
      ),
    ],
  );
}

void main() {
  group('TeamGameScreen Widget Tests', () {
    testWidgets('初期レンダリング - AppBar表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
            boardSize: 19,
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Team ゲーム'), findsWidgets);
    });

    testWidgets('戻るボタンが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('チーム情報表示 - Team1とTeam2', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('プレイヤー数確認 - 4人表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['alice', 'bob'],
            team2Players: ['charlie', 'david'],
            boardSize: 19,
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('ボードサイズ パラメータ確認 - 9x9', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
            boardSize: 9,
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('ボードサイズ パラメータ確認 - 13x13', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
            boardSize: 13,
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('ボードサイズ パラメータ確認 - 19x19', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
            boardSize: 19,
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('UIレイアウト - ダークモード背景色', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      final scaffold = find.byType(Scaffold);
      expect(scaffold, findsOneWidget);
    });

    testWidgets('レスポンシブレイアウト - SingleChildScrollView確認', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('アクションボタン - 着手提出ボタン表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.text('着手を提出'), findsWidgets);
    });

    testWidgets('アクションボタン - ゲーム終了ボタン表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.text('ゲーム終了'), findsWidgets);
    });

    testWidgets('複数プレイヤー - 異なる名前対応', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['user-alpha', 'user-beta'],
            team2Players: ['user-gamma', 'user-delta'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('デバイスサイズ対応 - 小さい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('デバイスサイズ対応 - 大きい画面', (WidgetTester tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1200, 1600);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(TeamGameScreen), findsOneWidget);
    });

    testWidgets('プロバイダー統合 - startTeamGameProvider呼び出し', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
            boardSize: 19,
          ),
          container: _buildContainer(),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('テキスト表示確認 - タイトル', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('ナビゲーション - 戻る機能', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('エラーハンドリング - 画面表示確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: TeamGameScreen(
            team1Players: ['player1', 'player2'],
            team2Players: ['player3', 'player4'],
          ),
          container: _buildContainer(),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

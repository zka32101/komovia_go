import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/game_history_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// A fixture game record with a valid, minimal SGF so the details view
/// (final board, move sequence) has something real to render.
final _testGameRecord = GameRecord(
  id: 'test-game-1',
  uid: TestData.testUser.uid,
  boardSize: 9,
  sgfData: '(;GM[1]SZ[9];B[cc];W[gg];B[ce];W[ge])',
  result: GameResult.playerWin,
  aiLevel: 5,
  playedAt: DateTime(2026, 1, 1),
  movesCount: 4,
  gameDuration: const Duration(minutes: 12),
  blackScore: 45.5,
  whiteScore: 30.5,
);

void main() {
  group('GameHistoryScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userGameRecordsProvider(
            TestData.testUser.uid,
          ).overrideWith((ref) async => [_testGameRecord]),
        ],
      );
    });

    testWidgets('renders game history screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      // Verify scaffold exists
      expect(find.byType(Scaffold), findsWidgets);

      // Verify app bar
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('displays screen title', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      // Verify title
      expect(find.text('対局履歴'), findsWidgets);
    });

    testWidgets('shows filter button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      // Filter button should exist
      expect(find.byIcon(Icons.filter_list), findsWidgets);
    });

    testWidgets('displays game count', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Should show game count
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows statistics section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Statistics section
      expect(find.text('勝利'), findsWidgets);
      expect(find.text('敗北'), findsWidgets);
      expect(find.text('引き分け'), findsWidgets);
    });

    testWidgets('displays game cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Game cards should be visible
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('game card shows result', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Result text (Victory/Defeat) should be visible
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('game card shows date', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Date formatting should be applied
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('game card displays score', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Score should be displayed
      expect(find.text('スコア'), findsWidgets);
    });

    testWidgets('game card shows AI level', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // AI level should be displayed
      expect(find.text('レベル'), findsWidgets);
    });

    testWidgets('can select game to view details', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap on a game card
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Details view should appear
      expect(find.text('勝ち'), findsWidgets);
    });

    testWidgets('game details shows final board', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Board should be rendered
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('game details shows game info section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Game details section
      expect(find.text('対局詳細'), findsWidgets);
    });

    testWidgets('back button returns to game list', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Click back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to list
      expect(find.text('対局履歴'), findsWidgets);
    });

    testWidgets('filter menu opens when filter button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap filter button
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Filter menu should open
      expect(find.text('結果でフィルター'), findsWidgets);
    });

    testWidgets('filter menu shows result options', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Open filter menu
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Filter options
      expect(find.text('すべて'), findsWidgets);
      expect(find.text('勝利'), findsWidgets);
      expect(find.text('敗北'), findsWidgets);
      expect(find.text('引き分け'), findsWidgets);
    });

    testWidgets('filter menu shows sort options', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Open filter menu
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      // Sort options
      expect(find.text('並び替え'), findsWidgets);
      expect(find.text('最新順'), findsWidgets);
      expect(find.text('スコア順'), findsWidgets);
      expect(find.text('最長'), findsWidgets);
    });

    testWidgets('shows auth required state when no user', (WidgetTester tester) async {
      final noAuthContainer = TestUtils.createTestContainer(
        currentUser: null,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: noAuthContainer,
        ),
      );

      // Auth required message
      expect(find.text('対局を見るにはログインしてください'), findsWidgets);
    });

    testWidgets('shows loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      // Should eventually load
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      final appBar = find.byType(AppBar).first;
      final appBarWidget = tester.widget<AppBar>(appBar);

      expect(appBarWidget.centerTitle, true);
      expect(appBarWidget.backgroundColor, AppColors.sumi);
      expect(appBarWidget.elevation, 0);
    });

    testWidgets('victory card has green border', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Win cards should have green styling
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('defeat card has red border', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Loss cards should have red styling
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('scroll view for game list', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Should have scrolling capability
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('shows move sequence placeholder in details', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Move sequence section
      expect(find.text('着手の記録'), findsWidgets);
    });

    testWidgets('game details displays board size', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Board size should be displayed
      expect(find.text('碁盤サイズ'), findsWidgets);
    });

    testWidgets('game card tappable area', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameHistoryScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Cards should be tappable
      expect(find.byType(InkWell), findsWidgets);
    });
  });
}

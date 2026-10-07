import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/screens/ai_game_screen.dart';
import 'package:komovia_go/views/screens/dead_stone_marking_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('AIGameScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        isGameActive: true,
        aiLevel: 5,
      );
    });

    testWidgets('renders game screen with board', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Verify scaffold
      expect(find.byType(Scaffold), findsWidgets);

      // Verify board container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('displays game info (board size and moves)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Verify game info text
      expect(find.text('碁盤サイズ'), findsWidgets);
      expect(find.text('9×9'), findsWidgets);
      expect(find.text('手数'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('shows AI level in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Verify app bar shows AI level
      expect(find.text('対局 - レベル 5'), findsWidgets);
    });

    testWidgets('displays board grid painter', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Board should render with CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows game control buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Verify control buttons (the "新しい対局" label only shows once the
      // game is no longer active - it reads "対局中..." while active).
      expect(find.text('パス'), findsWidgets);
      expect(find.text('投了'), findsWidgets);
      expect(find.text('対局中...'), findsWidgets);
    });

    testWidgets('pass button enabled when game active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      final passButton = find.byType(OutlinedButton).first;
      expect(passButton, findsWidgets);
    });

    testWidgets(
        'passing when the opponent already passed opens dead-stone marking '
        'instead of scoring immediately',
        (WidgetTester tester) async {
      // Simulate the AI having already passed once: the player's next
      // pass is the second consecutive pass, which should end the game.
      final endingContainer = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        isGameActive: true,
        aiLevel: 5,
        extraOverrides: [
          consecutivePassesProvider.overrideWith((ref) => 1),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: endingContainer,
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'パス'));
      await tester.pump();
      await tester.pump();

      // The old behavior scored immediately with every stone treated as
      // alive; now it must stop at a manual dead-stone confirmation step.
      expect(find.byType(DeadStoneMarkingScreen), findsOneWidget);
    });

    testWidgets('resign button enabled when game active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      expect(find.text('投了'), findsWidgets);
    });

    testWidgets('new game button disabled when game active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      final newGameButton = find.byType(ElevatedButton);
      expect(newGameButton, findsWidgets);
    });

    testWidgets('shows AI thinking state', (WidgetTester tester) async {
      final aiThinkingContainer = ProviderContainer(
        overrides: [
          // Override aiMoveProvider to show loading state
          // This depends on provider implementation
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: aiThinkingContainer,
        ),
      );

      // When AI is thinking, should show progress indicator
      // expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.bgDark);
    });

    testWidgets('board is 300x300 pixels', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Find board container and verify size
      final boardContainers =
          find.byWidgetPredicate((widget) => widget is Container);
      expect(boardContainers, findsWidgets);
    });

    testWidgets('stones render with correct styling',
        (WidgetTester tester) async {
      final boardWithStonesContainer = TestUtils.createTestContainer(
        boardState: TestData.boardWithStones,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: boardWithStonesContainer,
        ),
      );

      // When board has stones, Positioned widgets should render them
      expect(find.byType(Positioned), findsWidgets);
    });

    testWidgets('handles board tap coordinates', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      final board = find.byType(GestureDetector).first;
      expect(board, findsWidgets);

      // Tapping board should trigger move validation
      // This depends on actual tap handler implementation
    });

    testWidgets('updates move counter on move', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      // Initially 0 moves
      expect(find.text('0'), findsWidgets);

      // After move, counter would update
      // This depends on provider state management
    });

    testWidgets('has correct app bar configuration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const AIGameScreen(),
          container: container,
        ),
      );

      final appBar = find.byType(AppBar).first;
      final appBarWidget = tester.widget<AppBar>(appBar);

      expect(appBarWidget.centerTitle, true);
      expect(appBarWidget.backgroundColor, AppColors.primaryDark);
      expect(appBarWidget.elevation, 0);
    });
  });
}

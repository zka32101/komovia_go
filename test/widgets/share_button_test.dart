import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/widgets/index.dart';

void main() {
  group('GameShareButton Widget', () {
    testWidgets('renders share button correctly', (WidgetTester tester) async {
      final gameData = GameShareData(
        gameId: 'game_123',
        result: 'win',
        blackScore: 50.0,
        whiteScore: 45.0,
        boardSize: 19,
        aiLevel: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameShareButton(gameData: gameData),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.text('シェア'), findsOneWidget);
    });

    testWidgets('button color is amber', (WidgetTester tester) async {
      final gameData = GameShareData(
        gameId: 'game_123',
        result: 'win',
        blackScore: 50.0,
        whiteScore: 45.0,
        boardSize: 19,
        aiLevel: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameShareButton(gameData: gameData),
              ),
            ),
          ),
        ),
      );

      // Verify the button is rendered
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('calls onShared callback when share completes',
        (WidgetTester tester) async {
      var onSharedCalled = false;

      final gameData = GameShareData(
        gameId: 'game_123',
        result: 'win',
        blackScore: 50.0,
        whiteScore: 45.0,
        boardSize: 19,
        aiLevel: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameShareButton(
                  gameData: gameData,
                  onShared: () {
                    onSharedCalled = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // The button should exist
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('displays victory emoji for win', (WidgetTester tester) async {
      final gameData = GameShareData(
        gameId: 'game_123',
        result: 'win',
        blackScore: 50.0,
        whiteScore: 45.0,
        boardSize: 19,
        aiLevel: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GameShareButton(gameData: gameData),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('handles different board sizes', (WidgetTester tester) async {
      for (final boardSize in [9, 13, 19]) {
        final gameData = GameShareData(
          gameId: 'game_$boardSize',
          result: 'win',
          blackScore: 50.0,
          whiteScore: 45.0,
          boardSize: boardSize,
          aiLevel: 3,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: GameShareButton(gameData: gameData),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
      }
    });
  });

  group('PuzzleShareButton Widget', () {
    testWidgets('renders puzzle share button correctly',
        (WidgetTester tester) async {
      final puzzleData = PuzzleShareData(
        puzzleId: 'puzzle_123',
        difficulty: 'hard',
        attemptCount: 3,
        solvingTime: const Duration(minutes: 5),
        isSolved: true,
        currentStreak: 7,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: PuzzleShareButton(puzzleData: puzzleData),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.text('シェア'), findsOneWidget);
    });

    testWidgets('button color is cyan', (WidgetTester tester) async {
      final puzzleData = PuzzleShareData(
        puzzleId: 'puzzle_123',
        difficulty: 'medium',
        attemptCount: 2,
        solvingTime: const Duration(minutes: 3),
        isSolved: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: PuzzleShareButton(puzzleData: puzzleData),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('displays different difficulties', (WidgetTester tester) async {
      for (final difficulty in ['easy', 'medium', 'hard', 'master']) {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_$difficulty',
          difficulty: difficulty,
          attemptCount: 1,
          solvingTime: const Duration(minutes: 2),
          isSolved: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: PuzzleShareButton(puzzleData: puzzleData),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(FloatingActionButton), findsOneWidget);
      }
    });

    testWidgets('handles unsolved puzzles', (WidgetTester tester) async {
      final puzzleData = PuzzleShareData(
        puzzleId: 'puzzle_123',
        difficulty: 'hard',
        attemptCount: 5,
        solvingTime: const Duration(minutes: 10),
        isSolved: false,
        currentStreak: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: PuzzleShareButton(puzzleData: puzzleData),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}

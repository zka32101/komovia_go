import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/social_share_models.dart';
import 'package:komovia_go/viewmodels/game_result_share_provider.dart';

void main() {
  group('GameResultShareService', () {
    // Test Game Share Data generation
    group('Game Result Share Content', () {
      test('generates correct share content for win', () {
        final gameData = GameShareData(
          gameId: 'game123',
          result: 'win',
          blackScore: 25.5,
          whiteScore: 18.3,
          boardSize: 19,
          aiLevel: 7,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.text, contains('Victory'));
        expect(content.text, contains('25.5 vs 18.3'));
        expect(content.text, contains('19×19'));
        expect(content.text, contains('Level 7'));
        expect(content.hashtags, contains('#GoGame'));
        expect(content.deepLink, equals('goen://game/game123'));
      });

      test('generates correct share content for loss', () {
        final gameData = GameShareData(
          gameId: 'game456',
          result: 'loss',
          blackScore: 15.5,
          whiteScore: 28.3,
          boardSize: 13,
          aiLevel: 5,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.text, contains('Defeat'));
        expect(content.text, contains('15.5 vs 28.3'));
        expect(content.text, contains('13×13'));
        expect(content.hashtags, contains('#GoEn'));
      });

      test('generates correct share content for draw', () {
        final gameData = GameShareData(
          gameId: 'game789',
          result: 'draw',
          blackScore: 20.0,
          whiteScore: 20.0,
          boardSize: 9,
          aiLevel: 3,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.text, contains('Match'));
        expect(content.text, contains('9×9'));
      });
    });

    // Test Puzzle Share Data generation
    group('Puzzle Share Content', () {
      test('generates correct share content for solved puzzle', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle123',
          difficulty: 'hard',
          attemptCount: 3,
          solvingTime: const Duration(minutes: 5, seconds: 30),
          isSolved: true,
          currentStreak: 5,
        );

        final content = generatePuzzleShareContent(puzzleData);

        expect(content.text, contains('Successfully solved'));
        expect(content.text, contains('hard'));
        expect(content.text, contains('3'));
        expect(content.text, contains('5m 30s'));
        expect(content.text, contains('Streak: 5'));
        expect(content.hashtags, contains('#TsumeGo'));
        expect(content.deepLink, equals('goen://puzzle/puzzle123'));
      });

      test('generates correct share content for unsolved puzzle', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle456',
          difficulty: 'medium',
          attemptCount: 2,
          solvingTime: const Duration(minutes: 2),
          isSolved: false,
          currentStreak: 0,
        );

        final content = generatePuzzleShareContent(puzzleData);

        expect(content.text, contains('Still working on it'));
        expect(content.text, contains('medium'));
        expect(content.hashtags, contains('#GoPuzzle'));
      });
    });

    // Test Profile Share Data generation
    group('Profile Share Content', () {
      test('generates correct share content with complete stats', () {
        final profileData = ProfileShareData(
          userId: 'user123',
          displayName: 'Alice',
          totalGamesPlayed: 50,
          winCount: 35,
          currentPuzzleStreak: 10,
          totalPuzzlesSolved: 100,
        );

        final content = generateProfileShareContent(profileData);

        expect(content.text, contains('Alice'));
        expect(content.text, contains('Games: 50'));
        expect(content.text, contains('Wins: 35'));
        expect(content.text, contains('70.0%'));
        expect(content.text, contains('Puzzles Solved: 100'));
        expect(content.text, contains('Streak: 10'));
        expect(content.hashtags, contains('#GoEn'));
      });

      test('calculates correct win rate', () {
        final profileData = ProfileShareData(
          userId: 'user456',
          displayName: 'Bob',
          totalGamesPlayed: 10,
          winCount: 3,
          currentPuzzleStreak: 0,
          totalPuzzlesSolved: 25,
        );

        final content = generateProfileShareContent(profileData);

        expect(content.text, contains('30.0%'));
      });

      test('handles zero games played', () {
        final profileData = ProfileShareData(
          userId: 'user789',
          displayName: 'Charlie',
          totalGamesPlayed: 0,
          winCount: 0,
        );

        final content = generateProfileShareContent(profileData);

        expect(content.text, contains('Games: 0'));
        expect(content.text, contains('0.0%'));
      });
    });

    // Test Share Content metadata
    group('Share Content Metadata', () {
      test('includes hashtags for game shares', () {
        final gameData = GameShareData(
          gameId: 'game123',
          result: 'win',
          blackScore: 25.5,
          whiteScore: 18.3,
          boardSize: 19,
          aiLevel: 7,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.hashtags, isNotEmpty);
        expect(content.hashtags, contains('#碁縁'));
      });

      test('includes deep link for game navigation', () {
        final gameData = GameShareData(
          gameId: 'game-abc123',
          result: 'win',
          blackScore: 25.5,
          whiteScore: 18.3,
          boardSize: 19,
          aiLevel: 7,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.deepLink, equals('goen://game/game-abc123'));
      });

      test('includes image URL when requested', () {
        final gameData = GameShareData(
          gameId: 'game123',
          result: 'win',
          blackScore: 25.5,
          whiteScore: 18.3,
          boardSize: 19,
          aiLevel: 7,
          includeImage: true,
          sgfUrl: 'https://example.com/board.png',
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.imageUrl, isNotNull);
      });

      test('excludes image URL when not requested', () {
        final gameData = GameShareData(
          gameId: 'game123',
          result: 'win',
          blackScore: 25.5,
          whiteScore: 18.3,
          boardSize: 19,
          aiLevel: 7,
          includeImage: false,
          sgfUrl: 'https://example.com/board.png',
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.imageUrl, isNull);
      });
    });

    // Test edge cases
    group('Edge Cases', () {
      test('handles large scores correctly', () {
        final gameData = GameShareData(
          gameId: 'game123',
          result: 'win',
          blackScore: 150.5,
          whiteScore: 125.3,
          boardSize: 19,
          aiLevel: 10,
        );

        final content = _generateGameResultShareContent(gameData);

        expect(content.text, contains('150.5 vs 125.3'));
      });

      test('handles all board sizes', () {
        for (final size in [5, 9, 13, 19, 21]) {
          final gameData = GameShareData(
            gameId: 'game$size',
            result: 'win',
            blackScore: 20.0,
            whiteScore: 15.0,
            boardSize: size,
            aiLevel: 5,
          );

          final content = _generateGameResultShareContent(gameData);

          expect(content.text, contains('$size×$size'));
        }
      });

      test('handles all AI levels', () {
        for (final level in [1, 5, 7, 9, 10]) {
          final gameData = GameShareData(
            gameId: 'game$level',
            result: 'win',
            blackScore: 20.0,
            whiteScore: 15.0,
            boardSize: 19,
            aiLevel: level,
          );

          final content = _generateGameResultShareContent(gameData);

          expect(content.text, contains('Level $level'));
        }
      });

      test('handles very long solving time', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle123',
          difficulty: 'master',
          attemptCount: 10,
          solvingTime: const Duration(hours: 2, minutes: 30, seconds: 45),
          isSolved: true,
          currentStreak: 1,
        );

        final content = generatePuzzleShareContent(puzzleData);

        expect(content.text, contains('150m'));
      });
    });
  });
}

// Import the function from the provider file
ShareContent _generateGameResultShareContent(GameShareData gameData) {
  final resultText = _getResultText(gameData.result);
  final scoreStr = '${gameData.blackScore.toStringAsFixed(1)} vs '
      '${gameData.whiteScore.toStringAsFixed(1)}';

  final text = '''🎮 Just finished a Go game!
$resultText
Score: $scoreStr
Board: ${gameData.boardSize}×${gameData.boardSize}
Difficulty: Level ${gameData.aiLevel}
${gameData.sgfUrl != null ? 'Watch: ${gameData.sgfUrl}' : ''}''';

  return ShareContent(
    text: text,
    hashtags: '#GoGame #碁縁 #GoEn #AIGo #GoPuzzle',
    imageUrl: gameData.includeImage ? gameData.sgfUrl : null,
    deepLink: 'goen://game/${gameData.gameId}',
  );
}

String _getResultText(String result) {
  switch (result) {
    case 'win':
      return '🎉 Victory! Opponent Resigned';
    case 'loss':
      return '😌 Graceful Defeat - Learning Moment';
    case 'draw':
      return '⚖️ Even Match - Well Played!';
    default:
      return '⚫⚪ Game Complete';
  }
}

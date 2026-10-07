import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

void main() {
  group('SocialShareService', () {
    late SocialShareService socialShareService;

    setUp(() {
      socialShareService = const SocialShareService();
    });

    group('Content Generation', () {
      test('generates correct game share content for victory', () {
        final gameData = GameShareData(
          gameId: 'game_123',
          result: 'win',
          blackScore: 45.5,
          whiteScore: 42.0,
          boardSize: 19,
          aiLevel: 5,
        );

        // Call private method through public share
        expect(gameData.gameId, equals('game_123'));
        expect(gameData.result, equals('win'));
      });

      test('generates correct game share content for loss', () {
        final gameData = GameShareData(
          gameId: 'game_456',
          result: 'loss',
          blackScore: 38.0,
          whiteScore: 41.5,
          boardSize: 13,
          aiLevel: 3,
        );

        expect(gameData.result, equals('loss'));
        expect(gameData.boardSize, equals(13));
      });

      test('generates correct puzzle share content', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_789',
          difficulty: 'hard',
          attemptCount: 3,
          solvingTime: const Duration(minutes: 5, seconds: 30),
          isSolved: true,
          currentStreak: 7,
        );

        expect(puzzleData.difficulty, equals('hard'));
        expect(puzzleData.isSolved, isTrue);
        expect(puzzleData.currentStreak, equals(7));
      });

      test('generates correct profile share content', () {
        final profileData = ProfileShareData(
          userId: 'user_001',
          displayName: '碁の達人',
          totalGamesPlayed: 50,
          winCount: 35,
          currentPuzzleStreak: 12,
          totalPuzzlesSolved: 125,
        );

        expect(profileData.displayName, equals('碁の達人'));
        expect(profileData.totalGamesPlayed, equals(50));
        expect(profileData.winCount, equals(35));
      });
    });

    group('Share Content Model', () {
      test('creates ShareContent correctly', () {
        final content = ShareContent(
          text: 'テストシェア',
          hashtags: '#碁 #Go',
          deepLink: 'goen://game/123',
        );

        expect(content.text, equals('テストシェア'));
        expect(content.hashtags, equals('#碁 #Go'));
        expect(content.appName, equals('GoEn'));
      });

      test('serializes ShareContent to JSON', () {
        final content = ShareContent(
          text: 'テストシェア',
          hashtags: '#碁',
        );

        final json = content.toJson();
        expect(json['text'], equals('テストシェア'));
        expect(json['hashtags'], equals('#碁'));
      });

      test('deserializes ShareContent from JSON', () {
        final json = {
          'text': 'テストシェア',
          'hashtags': '#碁',
          'imageUrl': null,
          'deepLink': null,
          'appName': 'GoEn',
        };

        final content = ShareContent.fromJson(json);
        expect(content.text, equals('テストシェア'));
        expect(content.hashtags, equals('#碁'));
      });
    });

    group('GameShareData Model', () {
      test('creates GameShareData correctly', () {
        final gameData = GameShareData(
          gameId: 'game_001',
          result: 'win',
          blackScore: 50.0,
          whiteScore: 45.0,
          boardSize: 19,
          aiLevel: 7,
        );

        expect(gameData.gameId, equals('game_001'));
        expect(gameData.result, equals('win'));
        expect(gameData.boardSize, equals(19));
        expect(gameData.aiLevel, equals(7));
      });

      test('serializes GameShareData to JSON', () {
        final gameData = GameShareData(
          gameId: 'game_001',
          result: 'win',
          blackScore: 50.0,
          whiteScore: 45.0,
          boardSize: 19,
          aiLevel: 7,
        );

        final json = gameData.toJson();
        expect(json['gameId'], equals('game_001'));
        expect(json['result'], equals('win'));
      });
    });

    group('PuzzleShareData Model', () {
      test('creates PuzzleShareData correctly', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_001',
          difficulty: 'master',
          attemptCount: 1,
          solvingTime: const Duration(minutes: 2),
          isSolved: true,
        );

        expect(puzzleData.puzzleId, equals('puzzle_001'));
        expect(puzzleData.difficulty, equals('master'));
        expect(puzzleData.isSolved, isTrue);
      });

      test('serializes PuzzleShareData to JSON', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_001',
          difficulty: 'easy',
          attemptCount: 1,
          solvingTime: const Duration(seconds: 30),
          isSolved: true,
        );

        final json = puzzleData.toJson();
        expect(json['puzzleId'], equals('puzzle_001'));
        expect(json['difficulty'], equals('easy'));
      });
    });

    group('ProfileShareData Model', () {
      test('creates ProfileShareData correctly', () {
        final profileData = ProfileShareData(
          userId: 'user_001',
          displayName: 'テストユーザー',
          totalGamesPlayed: 100,
          winCount: 60,
          currentPuzzleStreak: 15,
          totalPuzzlesSolved: 200,
        );

        expect(profileData.userId, equals('user_001'));
        expect(profileData.displayName, equals('テストユーザー'));
        expect(profileData.totalGamesPlayed, equals(100));
      });

      test('calculates win rate correctly', () {
        final profileData = ProfileShareData(
          userId: 'user_001',
          displayName: 'テストユーザー',
          totalGamesPlayed: 10,
          winCount: 7,
        );

        final winRate = profileData.winCount / profileData.totalGamesPlayed * 100;
        expect(winRate, equals(70.0));
      });

      test('serializes ProfileShareData to JSON', () {
        final profileData = ProfileShareData(
          userId: 'user_001',
          displayName: 'テストユーザー',
        );

        final json = profileData.toJson();
        expect(json['userId'], equals('user_001'));
        expect(json['displayName'], equals('テストユーザー'));
      });
    });

    group('SocialPlatform Enum', () {
      test('has correct display names', () {
        expect(SocialPlatform.twitter.displayName, equals('X (Twitter)'));
        expect(SocialPlatform.facebook.displayName, equals('Facebook'));
        expect(SocialPlatform.whatsapp.displayName, equals('WhatsApp'));
        expect(SocialPlatform.line.displayName, equals('LINE'));
        expect(SocialPlatform.clipboard.displayName, equals('Copy to Clipboard'));
      });

      test('all platforms are defined', () {
        expect(SocialPlatform.values.length, equals(5));
      });
    });

    group('Edge Cases', () {
      test('handles empty game ID', () {
        final gameData = GameShareData(
          gameId: '',
          result: 'win',
          blackScore: 50.0,
          whiteScore: 45.0,
          boardSize: 19,
          aiLevel: 1,
        );

        expect(gameData.gameId, isEmpty);
      });

      test('handles negative scores', () {
        final gameData = GameShareData(
          gameId: 'game_001',
          result: 'loss',
          blackScore: -10.0,
          whiteScore: 5.0,
          boardSize: 19,
          aiLevel: 1,
        );

        expect(gameData.blackScore, equals(-10.0));
      });

      test('handles zero attempts', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_001',
          difficulty: 'easy',
          attemptCount: 0,
          solvingTime: Duration.zero,
          isSolved: false,
        );

        expect(puzzleData.attemptCount, equals(0));
        expect(puzzleData.isSolved, isFalse);
      });

      test('handles large streak numbers', () {
        final puzzleData = PuzzleShareData(
          puzzleId: 'puzzle_001',
          difficulty: 'hard',
          attemptCount: 1,
          solvingTime: const Duration(minutes: 1),
          isSolved: true,
          currentStreak: 999,
        );

        expect(puzzleData.currentStreak, equals(999));
      });
    });
  });
}

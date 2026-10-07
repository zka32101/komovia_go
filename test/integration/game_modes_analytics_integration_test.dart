import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/extended_game_models.dart';
import 'package:komovia_go/models/game_record.dart' as real_game;
import 'package:komovia_go/services/game_preset_service.dart';
import 'package:komovia_go/services/analytics_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GamePresetService presetService;
  late AnalyticsService analyticsService;

  const testUserId = 'test-user-analytics';

  setUpAll(() {
    // Real FirebaseFirestore.instance has no backend to talk to under
    // flutter_test; inject a shared in-memory fake instead.
    firestore = FakeFirebaseFirestore();
    presetService = GamePresetService(firestore: firestore);
    analyticsService = AnalyticsService(firestore: firestore);
  });

  // AnalyticsService reads from the top-level `gameRecords` collection that
  // saveGameRecordProvider (game_provider.dart) actually writes real AI
  // games to -- it no longer has its own recordGameResult write path (that
  // wrote to a `users/{uid}/gameRecords` subcollection nothing else ever
  // read). Seed test data the same way the real app does.
  Future<void> seedGameRecord({
    required String gameId,
    required real_game.GameResult result,
    required int boardSize,
    required int aiLevel,
    required DateTime playedAt,
    required int durationSeconds,
    double? blackScore,
    double? whiteScore,
  }) async {
    final record = real_game.GameRecord(
      id: gameId,
      uid: testUserId,
      boardSize: boardSize,
      sgfData: '',
      result: result,
      aiLevel: aiLevel,
      playedAt: playedAt,
      gameDuration: Duration(seconds: durationSeconds),
      blackScore: blackScore,
      whiteScore: whiteScore,
    );
    await firestore
        .collection('gameRecords')
        .doc(gameId)
        .set(record.toFirestore());
  }

  group('Game Preset Service Integration Tests', () {
    test('Create default presets for new user', () async {
      final created = await presetService.createDefaultPresets(
        userId: testUserId,
      );

      expect(created, isTrue);
    });

    test('Get user presets', () async {
      final presets = await presetService.getUserPresets(userId: testUserId);

      expect(presets, isA<List<GamePreset>>());
    });

    test('Create custom preset', () async {
      final created = await presetService.createPreset(
        userId: testUserId,
        name: 'Custom Blitz Setup',
        gameMode: 'blitz',
        boardSize: 19,
        aiLevel: 7,
        playerColor: 'black',
      );

      expect(created, isTrue);
    });

    test('Get presets by game mode', () async {
      final presets = await presetService.getPresetsByMode(
        userId: testUserId,
        gameMode: 'blitz',
      );

      expect(presets, isA<List<GamePreset>>());
    });

    test('Get most used presets', () async {
      final presets = await presetService.getMostUsedPresets(
        userId: testUserId,
        limit: 5,
      );

      expect(presets, isA<List<GamePreset>>());
    });

    test('Increment preset usage', () async {
      final presets = await presetService.getUserPresets(userId: testUserId);

      if (presets.isNotEmpty) {
        final incremented = await presetService.incrementPresetUsage(
          userId: testUserId,
          presetId: presets[0].id,
        );

        expect(incremented, isTrue);
      }
    });

    test('Update preset', () async {
      final presets = await presetService.getUserPresets(userId: testUserId);

      if (presets.isNotEmpty) {
        final preset = presets[0];
        final updated = await presetService.updatePreset(
          userId: testUserId,
          presetId: preset.id,
          name: 'Updated Preset Name',
          gameMode: preset.gameMode,
          boardSize: preset.boardSize,
          aiLevel: preset.aiLevel,
        );

        expect(updated, isTrue);
      }
    });

    test('Delete preset', () async {
      final presets = await presetService.getUserPresets(userId: testUserId);

      if (presets.isNotEmpty) {
        final deleted = await presetService.deletePreset(
          userId: testUserId,
          presetId: presets[0].id,
        );

        expect(deleted, isTrue);
      }
    });

    test('Get preset count', () async {
      final count = await presetService.getPresetCount(userId: testUserId);

      expect(count, isA<int>());
      expect(count, greaterThanOrEqualTo(0));
    });
  });

  group('Analytics Service Integration Tests', () {
    test('Record game result', () async {
      await seedGameRecord(
        gameId: 'game-1',
        result: real_game.GameResult.playerWin,
        blackScore: 25.5,
        whiteScore: 18.3,
        boardSize: 19,
        aiLevel: 5,
        playedAt: DateTime.now(),
        durationSeconds: 600,
      );

      final games = await analyticsService.getRecentGames(userId: testUserId);
      expect(games.any((g) => g.gameId == 'game-1'), isTrue);
    });

    test('Get user statistics', () async {
      final stats = await analyticsService.getUserStatistics(
        userId: testUserId,
      );

      expect(stats, isA<GameStatistics?>());
      if (stats != null) {
        expect(stats.userId, equals(testUserId));
      }
    });

    test('Get recent games', () async {
      final games = await analyticsService.getRecentGames(
        userId: testUserId,
        limit: 20,
      );

      expect(games, isA<List<GameRecord>>());
    });

    test('Get win rate by board size', () async {
      final winRates = await analyticsService.getWinRateByBoardSize(
        userId: testUserId,
      );

      expect(winRates, isA<Map<String, double>>());
    });

    test('Get win rate by AI level', () async {
      final winRates = await analyticsService.getWinRateByAiLevel(
        userId: testUserId,
      );

      expect(winRates, isA<Map<int, double>>());
    });

    test('Get game distribution by mode', () async {
      final distribution = await analyticsService.getGameDistributionByMode(
        userId: testUserId,
        daysBack: 30,
      );

      expect(distribution, isA<Map<String, int>>());
    });

    test('Get average game duration', () async {
      final duration = await analyticsService.getAverageGameDuration(
        userId: testUserId,
      );

      expect(duration, isA<double>());
      expect(duration, greaterThanOrEqualTo(0));
    });

    test('Check achievements', () async {
      final achievements = await analyticsService.checkAchievements(
        userId: testUserId,
      );

      expect(achievements, isA<List<Achievement>>());
    });

    test('Get unlocked achievements', () async {
      final achievements = await analyticsService.getUnlockedAchievements(
        userId: testUserId,
      );

      expect(achievements, isA<List<Achievement>>());
    });
  });

  group('Game Presets & Analytics Integration Scenarios', () {
    test('Complete preset creation and usage workflow', () async {
      // Create a preset
      final created = await presetService.createPreset(
        userId: testUserId,
        name: 'Tournament Preset',
        gameMode: 'blitz',
        boardSize: 19,
        aiLevel: 8,
      );
      expect(created, isTrue);

      // Get presets
      final presets = await presetService.getUserPresets(userId: testUserId);
      expect(presets, isNotEmpty);

      // Use the preset (simulate game)
      if (presets.isNotEmpty) {
        await presetService.incrementPresetUsage(
          userId: testUserId,
          presetId: presets[0].id,
        );

        // Record game result
        await seedGameRecord(
          gameId: 'game-preset-test',
          result: real_game.GameResult.playerWin,
          blackScore: 28.5,
          whiteScore: 15.3,
          boardSize: 19,
          aiLevel: 8,
          playedAt: DateTime.now(),
          durationSeconds: 720,
        );

        final games = await analyticsService.getRecentGames(userId: testUserId);
        expect(games.any((g) => g.gameId == 'game-preset-test'), isTrue);
      }
    });

    test('Complete analytics workflow with multiple games', () async {
      // Record multiple game results
      await seedGameRecord(
        gameId: 'game-a1',
        result: real_game.GameResult.playerWin,
        blackScore: 25.5,
        whiteScore: 18.3,
        boardSize: 19,
        aiLevel: 5,
        playedAt: DateTime.now().subtract(const Duration(days: 2)),
        durationSeconds: 600,
      );
      await seedGameRecord(
        gameId: 'game-a2',
        result: real_game.GameResult.aiWin,
        blackScore: 18.5,
        whiteScore: 22.3,
        boardSize: 19,
        aiLevel: 6,
        playedAt: DateTime.now().subtract(const Duration(days: 1)),
        durationSeconds: 1800,
      );
      await seedGameRecord(
        gameId: 'game-a3',
        result: real_game.GameResult.playerWin,
        blackScore: 30.5,
        whiteScore: 12.3,
        boardSize: 13,
        aiLevel: 4,
        playedAt: DateTime.now(),
        durationSeconds: 400,
      );

      // Get statistics
      final stats = await analyticsService.getUserStatistics(
        userId: testUserId,
      );
      expect(stats, isNotNull);

      // Get detailed analytics
      final recentGames = await analyticsService.getRecentGames(
        userId: testUserId,
        limit: 10,
      );
      expect(recentGames, isNotEmpty);

      final winRateBySize = await analyticsService.getWinRateByBoardSize(
        userId: testUserId,
      );
      expect(winRateBySize, isA<Map<String, double>>());

      final winRateByLevel = await analyticsService.getWinRateByAiLevel(
        userId: testUserId,
      );
      expect(winRateByLevel, isA<Map<int, double>>());

      final distribution = await analyticsService.getGameDistributionByMode(
        userId: testUserId,
        daysBack: 30,
      );
      expect(distribution, isNotEmpty);
    });

    test('Achievement unlock workflow', () async {
      // Record first win
      await seedGameRecord(
        gameId: 'first-win-game',
        result: real_game.GameResult.playerWin,
        blackScore: 25.5,
        whiteScore: 18.3,
        boardSize: 9,
        aiLevel: 1,
        playedAt: DateTime.now(),
        durationSeconds: 300,
      );

      // Check achievements
      final achievements = await analyticsService.checkAchievements(
        userId: testUserId,
      );

      expect(achievements, isA<List<Achievement>>());

      // Get unlocked achievements
      final unlocked = await analyticsService.getUnlockedAchievements(
        userId: testUserId,
      );

      expect(unlocked, isA<List<Achievement>>());
    });

    test('Preset usage with game statistics correlation', () async {
      // Get most used presets
      final mostUsed = await presetService.getMostUsedPresets(
        userId: testUserId,
        limit: 3,
      );

      expect(mostUsed, isA<List<GamePreset>>());

      // Get game statistics filtered by preset characteristics
      if (mostUsed.isNotEmpty) {
        final preset = mostUsed[0];
        final stats = await analyticsService.getUserStatistics(
          userId: testUserId,
        );

        if (stats != null) {
          // Verify that statistics exist
          expect(stats.userId, equals(testUserId));
          expect(stats.totalGamesPlayed, greaterThanOrEqualTo(0));
        }
      }
    });
  });
}

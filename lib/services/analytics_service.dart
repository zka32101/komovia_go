import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:logger/logger.dart';
import '../models/extended_game_models.dart';
import '../models/game_record.dart' as real_game;

final _logger = Logger();

/// Service for game analytics and statistics
///
/// Reads from the top-level `gameRecords` collection -- the one
/// saveGameRecordProvider (game_provider.dart) actually writes real AI
/// games to via game_record.dart's GameRecord/toFirestore(). This service
/// previously read/wrote a `users/{uid}/gameRecords` subcollection using a
/// completely different, never-written GameRecord shape (this file's own,
/// below), so every method here always returned empty/null regardless of
/// how many games a user had actually played.
class AnalyticsService {
  final FirebaseFirestore _firestore;

  AnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Converts a real AI-game record into this service's own GameRecord
  /// shape (extended_game_models.dart), which GameStatistics/achievements
  /// are built around. Real AI games have no gameMode concept of their
  /// own (they're always vs. the AI), so gameMode is fixed to 'ai'.
  GameRecord _fromRealRecord(real_game.GameRecord g) {
    final result = switch (g.result) {
      real_game.GameResult.playerWin => 'win',
      real_game.GameResult.aiWin => 'loss',
      real_game.GameResult.draw => 'draw',
      real_game.GameResult.resignation => 'loss',
      real_game.GameResult.unknown => 'draw',
    };
    return GameRecord(
      gameId: g.id,
      result: result,
      blackScore: g.blackScore ?? 0,
      whiteScore: g.whiteScore ?? 0,
      boardSize: g.boardSize,
      aiLevel: g.aiLevel,
      gameMode: 'ai',
      playedAt: g.playedAt,
      durationSeconds: g.gameDuration?.inSeconds ?? 0,
      moveCount: g.movesCount ?? 0,
    );
  }

  /// Get user game statistics, computed on demand from the real game
  /// records rather than a separately-maintained summary doc.
  Future<GameStatistics?> getUserStatistics({required String userId}) async {
    try {
      _logger.i('Getting statistics for user: $userId');

      final games = await getRecentGames(userId: userId, limit: 1000);
      if (games.isEmpty) return null;

      return _computeStatistics(userId, games);
    } catch (e) {
      _logger.e('Failed to get user statistics: $e');
      return null;
    }
  }

  /// Get recent games from the real `gameRecords` collection.
  Future<List<GameRecord>> getRecentGames({
    required String userId,
    int limit = 20,
  }) async {
    try {
      _logger.i('Getting recent games for user: $userId');

      final querySnapshot = await _firestore
          .collection('gameRecords')
          .where('uid', isEqualTo: userId)
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => _fromRealRecord(real_game.GameRecord.fromFirestore(doc)))
          .toList();
    } catch (e) {
      _logger.e('Failed to get recent games: $e');
      return [];
    }
  }

  /// Get win rate by board size
  Future<Map<String, double>> getWinRateByBoardSize({
    required String userId,
  }) async {
    try {
      _logger.i('Getting win rate by board size for: $userId');

      final games = await getRecentGames(userId: userId, limit: 100);

      final statsMap = <String, (int wins, int total)>{};

      for (final game in games) {
        final sizeKey = '${game.boardSize}x${game.boardSize}';
        final isWin = game.result == 'win' ? 1 : 0;

        if (statsMap.containsKey(sizeKey)) {
          final current = statsMap[sizeKey]!;
          statsMap[sizeKey] = (current.$1 + isWin, current.$2 + 1);
        } else {
          statsMap[sizeKey] = (isWin, 1);
        }
      }

      final winRates = <String, double>{};
      for (final entry in statsMap.entries) {
        winRates[entry.key] = (entry.value.$1 / entry.value.$2) * 100;
      }

      return winRates;
    } catch (e) {
      _logger.e('Failed to get win rate by board size: $e');
      return {};
    }
  }

  /// Get win rate by AI level
  Future<Map<int, double>> getWinRateByAiLevel({
    required String userId,
  }) async {
    try {
      _logger.i('Getting win rate by AI level for: $userId');

      final games = await getRecentGames(userId: userId, limit: 100);

      final statsMap = <int, (int wins, int total)>{};

      for (final game in games) {
        final isWin = game.result == 'win' ? 1 : 0;

        if (statsMap.containsKey(game.aiLevel)) {
          final current = statsMap[game.aiLevel]!;
          statsMap[game.aiLevel] = (current.$1 + isWin, current.$2 + 1);
        } else {
          statsMap[game.aiLevel] = (isWin, 1);
        }
      }

      final winRates = <int, double>{};
      for (final entry in statsMap.entries) {
        winRates[entry.key] = (entry.value.$1 / entry.value.$2) * 100;
      }

      return winRates;
    } catch (e) {
      _logger.e('Failed to get win rate by AI level: $e');
      return {};
    }
  }

  /// Get games by mode distribution. Real AI games have no gameMode of
  /// their own, so every game counts as 'ai' -- kept for interface
  /// compatibility with GameModeAnalyticsDashboard-style widgets rather
  /// than removed outright.
  Future<Map<String, int>> getGameDistributionByMode({
    required String userId,
    int daysBack = 30,
  }) async {
    try {
      _logger.i('Getting game distribution for user: $userId');

      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

      final querySnapshot = await _firestore
          .collection('gameRecords')
          .where('uid', isEqualTo: userId)
          .where('playedAt', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (querySnapshot.docs.isEmpty) return {};

      return {'ai': querySnapshot.docs.length};
    } catch (e) {
      _logger.e('Failed to get game distribution: $e');
      return {};
    }
  }

  /// Get average game duration
  Future<double> getAverageGameDuration({required String userId}) async {
    try {
      _logger.i('Getting average game duration for: $userId');

      final games = await getRecentGames(userId: userId, limit: 50);

      if (games.isEmpty) return 0.0;

      final totalDuration = games.fold<int>(
        0,
        (sum, game) => sum + game.durationSeconds,
      );

      return totalDuration / games.length / 60; // Convert to minutes
    } catch (e) {
      _logger.e('Failed to get average game duration: $e');
      return 0.0;
    }
  }

  /// Stream user statistics (real-time), recomputed from the real
  /// `gameRecords` collection whenever it changes.
  Stream<GameStatistics?> streamUserStatistics({required String userId}) {
    return _firestore
        .collection('gameRecords')
        .where('uid', isEqualTo: userId)
        .orderBy('playedAt', descending: true)
        .limit(1000)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final games = snapshot.docs
          .map((doc) => _fromRealRecord(real_game.GameRecord.fromFirestore(doc)))
          .toList();
      return _computeStatistics(userId, games);
    });
  }

  GameStatistics _computeStatistics(String userId, List<GameRecord> games) {
    final totalGames = games.length;
    final totalWins = games.where((g) => g.result == 'win').length;
    final totalLosses = games.where((g) => g.result == 'loss').length;
    final winRate = totalGames > 0 ? (totalWins / totalGames) * 100 : 0.0;

    final avgDuration = games.isEmpty
        ? 0.0
        : games.fold<int>(0, (sum, game) => sum + game.durationSeconds) /
            games.length /
            60;

    return GameStatistics(
      userId: userId,
      totalGamesPlayed: totalGames,
      totalWins: totalWins,
      totalLosses: totalLosses,
      recentGames: games.take(10).toList(),
      winRate: winRate,
      averageGameDuration: avgDuration,
      favoriteGameMode: _getFavoritMode(games),
      favoriteAiLevel: _getFavoriteLevel(games),
      favoriteBoardSize: _getFavoriteBoardSize(games).toString(),
      lastPlayedAt: games.isNotEmpty ? games.first.playedAt : null,
      gamesByMode: totalGames > 0 ? {'ai': totalGames} : {},
    );
  }

  /// Check and unlock achievements
  Future<List<Achievement>> checkAchievements({required String userId}) async {
    try {
      _logger.i('Checking achievements for user: $userId');

      final stats = await getUserStatistics(userId: userId);
      if (stats == null) return [];

      final unlockedAchievements = <Achievement>[];

      // Check each predefined achievement
      for (final achievement in PredefinedAchievements.all) {
        final isUnlocked = _checkAchievementCondition(achievement, stats);

        if (isUnlocked && !achievement.isUnlocked) {
          unlockedAchievements.add(
            achievement.copyWith(
              isUnlocked: true,
              unlockedAt: DateTime.now(),
            ),
          );

          // Save to Firestore
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('achievements')
              .doc(achievement.id)
              .set(unlockedAchievements.last.toJson());
        }
      }

      return unlockedAchievements;
    } catch (e) {
      _logger.e('Failed to check achievements: $e');
      return [];
    }
  }

  /// Get user's unlocked achievements
  Future<List<Achievement>> getUnlockedAchievements({
    required String userId,
  }) async {
    try {
      _logger.i('Getting unlocked achievements for: $userId');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .where('isUnlocked', isEqualTo: true)
          .get();

      final achievements = querySnapshot.docs
          .map((doc) => Achievement.fromJson(doc.data()))
          .toList();

      return achievements;
    } catch (e) {
      _logger.e('Failed to get unlocked achievements: $e');
      return [];
    }
  }

  /// Private helper methods

  String _getFavoritMode(List<GameRecord> games) {
    final modeCount = <String, int>{};
    for (final game in games) {
      modeCount[game.gameMode] = (modeCount[game.gameMode] ?? 0) + 1;
    }
    return maxBy(modeCount.entries, (e) => e.value)?.key ?? 'unknown';
  }

  int _getFavoriteLevel(List<GameRecord> games) {
    final levelCount = <int, int>{};
    for (final game in games) {
      levelCount[game.aiLevel] = (levelCount[game.aiLevel] ?? 0) + 1;
    }
    return maxBy(levelCount.entries, (e) => e.value)?.key ?? 0;
  }

  int _getFavoriteBoardSize(List<GameRecord> games) {
    final sizeCount = <int, int>{};
    for (final game in games) {
      sizeCount[game.boardSize] = (sizeCount[game.boardSize] ?? 0) + 1;
    }
    return maxBy(sizeCount.entries, (e) => e.value)?.key ?? 19;
  }

  bool _checkAchievementCondition(
    Achievement achievement,
    GameStatistics stats,
  ) {
    switch (achievement.id) {
      case 'first_win':
        return stats.totalWins >= 1;
      case 'streak_5':
        return stats.totalWins >= 5;
      case 'explorer':
        return stats.gamesByMode.length >= 3;
      case 'master_10':
        return stats.totalWins >= 10 && stats.favoriteAiLevel >= 10;
      case 'century':
        return stats.totalGamesPlayed >= 100;
      case 'boardsize_collector':
        return stats.gamesByMode.values.any((v) => v >= 1);
      default:
        return false;
    }
  }
}

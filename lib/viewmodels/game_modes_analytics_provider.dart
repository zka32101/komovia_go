import 'package:riverpod/riverpod.dart';
import '../models/extended_game_models.dart';
import '../services/game_preset_service.dart';
import '../services/analytics_service.dart';

// ==================== Game Preset Service Provider ====================

/// Game Preset Service Provider
final gamePresetServiceProvider = Provider<GamePresetService>((ref) {
  return GamePresetService();
});

/// Analytics Service Provider
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

// ==================== Phase 70: Game Preset Providers ====================

/// Get all presets for current user
final userGamePresetsProvider = FutureProvider.family<List<GamePreset>, String>(
  (ref, userId) async {
    final service = ref.watch(gamePresetServiceProvider);
    return service.getUserPresets(userId: userId);
  },
);

/// Stream user presets (real-time)
final userGamePresetsStreamProvider =
    StreamProvider.family<List<GamePreset>, String>(
  (ref, userId) {
    final service = ref.watch(gamePresetServiceProvider);
    return service.streamUserPresets(userId: userId);
  },
);

/// Get presets by game mode
final presetsByModeProvider =
    FutureProvider.family<List<GamePreset>, (String, String)>(
  (ref, params) async {
    final (userId, gameMode) = params;
    final service = ref.watch(gamePresetServiceProvider);
    return service.getPresetsByMode(userId: userId, gameMode: gameMode);
  },
);

/// Get most used presets
final mostUsedPresetsProvider =
    FutureProvider.family<List<GamePreset>, (String, int)>(
  (ref, params) async {
    final (userId, limit) = params;
    final service = ref.watch(gamePresetServiceProvider);
    return service.getMostUsedPresets(userId: userId, limit: limit);
  },
);

/// Create new game preset
final createGamePresetProvider = FutureProvider.family<bool,
    ({
      String userId,
      String name,
      String gameMode,
      int boardSize,
      int aiLevel,
      String? playerColor,
      HandicapSettings? handicap,
    })>(
  (ref, params) async {
    final service = ref.watch(gamePresetServiceProvider);
    return service.createPreset(
      userId: params.userId,
      name: params.name,
      gameMode: params.gameMode,
      boardSize: params.boardSize,
      aiLevel: params.aiLevel,
      playerColor: params.playerColor,
      handicap: params.handicap,
    );
  },
);

/// Update existing preset
final updateGamePresetProvider = FutureProvider.family<bool,
    ({
      String userId,
      String presetId,
      String name,
      String gameMode,
      int boardSize,
      int aiLevel,
      String? playerColor,
      HandicapSettings? handicap,
    })>(
  (ref, params) async {
    final service = ref.watch(gamePresetServiceProvider);
    return service.updatePreset(
      userId: params.userId,
      presetId: params.presetId,
      name: params.name,
      gameMode: params.gameMode,
      boardSize: params.boardSize,
      aiLevel: params.aiLevel,
      playerColor: params.playerColor,
      handicap: params.handicap,
    );
  },
);

/// Delete preset
final deleteGamePresetProvider =
    FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (userId, presetId) = params;
    final service = ref.watch(gamePresetServiceProvider);
    return service.deletePreset(userId: userId, presetId: presetId);
  },
);

/// Increment preset usage
final incrementPresetUsageProvider =
    FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (userId, presetId) = params;
    final service = ref.watch(gamePresetServiceProvider);
    return service.incrementPresetUsage(userId: userId, presetId: presetId);
  },
);

// ==================== Phase 71: Analytics Providers ====================

/// Get user game statistics
final userStatisticsProvider =
    FutureProvider.family<GameStatistics?, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.getUserStatistics(userId: userId);
  },
);

/// Stream user statistics (real-time)
final userStatisticsStreamProvider =
    StreamProvider.family<GameStatistics?, String>(
  (ref, userId) {
    final service = ref.watch(analyticsServiceProvider);
    return service.streamUserStatistics(userId: userId);
  },
);

/// Get recent games
final recentGamesProvider =
    FutureProvider.family<List<GameRecord>, (String, int)>(
  (ref, params) async {
    final (userId, limit) = params;
    final service = ref.watch(analyticsServiceProvider);
    return service.getRecentGames(userId: userId, limit: limit);
  },
);

/// Get win rate by board size
final winRateByBoardSizeProvider =
    FutureProvider.family<Map<String, double>, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.getWinRateByBoardSize(userId: userId);
  },
);

/// Get win rate by AI level
final winRateByAiLevelProvider =
    FutureProvider.family<Map<int, double>, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.getWinRateByAiLevel(userId: userId);
  },
);

/// Get game distribution by mode
final gameDistributionProvider =
    FutureProvider.family<Map<String, int>, (String, int)>(
  (ref, params) async {
    final (userId, daysBack) = params;
    final service = ref.watch(analyticsServiceProvider);
    return service.getGameDistributionByMode(userId: userId, daysBack: daysBack);
  },
);

/// Get average game duration
final averageGameDurationProvider =
    FutureProvider.family<double, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.getAverageGameDuration(userId: userId);
  },
);

/// Get unlocked achievements
final unlockedAchievementsProvider =
    FutureProvider.family<List<Achievement>, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.getUnlockedAchievements(userId: userId);
  },
);

/// Check and unlock new achievements
final checkAchievementsProvider = FutureProvider.family<List<Achievement>, String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    return service.checkAchievements(userId: userId);
  },
);

// ==================== Computed/Combined Providers ====================

/// Get all achievement definitions
final achievementDefsProvider = Provider<List<Achievement>>((ref) {
  return PredefinedAchievements.all;
});

/// 対局終了直後に検出された、まだ画面に見せていない新規解除実績。
/// `game_provider.dart`の`_checkAndRecordAchievements`（対局保存後に
/// best-effortで実行される）がここに書き込み、`GameResultScreen`が
/// `ref.listen`で拾ってトースト表示した後に空リストへ戻す。
final newlyUnlockedAchievementsProvider = StateProvider<List<Achievement>>((ref) {
  return [];
});

/// Get achievement progress
final achievementProgressProvider = FutureProvider.family<
    List<({Achievement achievement, double progress})>,
    String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    final stats = await service.getUserStatistics(userId: userId);
    if (stats == null) return [];

    return PredefinedAchievements.all.map((achievement) {
      final progress = _getAchievementProgress(achievement, stats);
      return (achievement: achievement, progress: progress);
    }).toList();
  },
);

/// Dashboard summary data
final dashboardSummaryProvider = FutureProvider.family<
    ({
      int totalGames,
      int totalWins,
      double winRate,
      double avgDuration,
      String favoriteMode,
      int favoriteLevel,
    })?,
    String>(
  (ref, userId) async {
    final service = ref.watch(analyticsServiceProvider);
    final stats = await service.getUserStatistics(userId: userId);

    if (stats == null) return null;

    return (
      totalGames: stats.totalGamesPlayed,
      totalWins: stats.totalWins,
      winRate: stats.winRate,
      avgDuration: stats.averageGameDuration,
      favoriteMode: stats.favoriteGameMode,
      favoriteLevel: stats.favoriteAiLevel,
    );
  },
);

double _getAchievementProgress(
  Achievement achievement,
  GameStatistics stats,
) {
  switch (achievement.id) {
    case 'first_win':
      return stats.totalWins >= 1 ? 100.0 : (stats.totalWins / 1) * 100;
    case 'streak_5':
      return (stats.totalWins / 5) * 100;
    case 'explorer':
      return (stats.gamesByMode.length / 4) * 100;
    case 'master_10':
      return ((stats.totalWins / 10) * 100).clamp(0, 100);
    case 'century':
      return (stats.totalGamesPlayed / 100) * 100;
    case 'boardsize_collector':
      return stats.gamesByMode.isEmpty ? 0.0 : 100.0;
    default:
      return 0.0;
  }
}

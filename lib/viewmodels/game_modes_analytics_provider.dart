import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import '../models/extended_game_models.dart';
import '../models/leaderboard.dart';
import '../services/game_preset_service.dart';
import '../services/analytics_service.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';
import 'notification_provider.dart';

final _logger = Logger();

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
///
/// A plain action provider (not `.family`) so one-shot preset creation
/// calls never grow the provider container's cache: a `.family` keyed on
/// a record containing the preset's free-text name/settings would mint a
/// brand-new, never-evicted cache entry for every distinct preset a user
/// ever creates.
final createGamePresetProvider = Provider<
    Future<bool> Function({
      required String userId,
      required String name,
      required String gameMode,
      required int boardSize,
      required int aiLevel,
      String? playerColor,
      HandicapSettings? handicap,
    })>((ref) {
  final service = ref.watch(gamePresetServiceProvider);
  return ({
    required userId,
    required name,
    required gameMode,
    required boardSize,
    required aiLevel,
    playerColor,
    handicap,
  }) {
    return service.createPreset(
      userId: userId,
      name: name,
      gameMode: gameMode,
      boardSize: boardSize,
      aiLevel: aiLevel,
      playerColor: playerColor,
      handicap: handicap,
    );
  };
});

/// Update existing preset
///
/// Same plain-action shape as [createGamePresetProvider], for the same
/// cache-growth reason.
final updateGamePresetProvider = Provider<
    Future<bool> Function({
      required String userId,
      required String presetId,
      required String name,
      required String gameMode,
      required int boardSize,
      required int aiLevel,
      String? playerColor,
      HandicapSettings? handicap,
    })>((ref) {
  final service = ref.watch(gamePresetServiceProvider);
  return ({
    required userId,
    required presetId,
    required name,
    required gameMode,
    required boardSize,
    required aiLevel,
    playerColor,
    handicap,
  }) {
    return service.updatePreset(
      userId: userId,
      presetId: presetId,
      name: name,
      gameMode: gameMode,
      boardSize: boardSize,
      aiLevel: aiLevel,
      playerColor: playerColor,
      handicap: handicap,
    );
  };
});

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
/// `checkAndRecordAchievementsAfterGame`（各ゲームモードの対局終了処理から
/// best-effortで呼ばれる）がここに書き込み、`GameResultScreen`が
/// `ref.listen`で拾ってトースト表示した後に空リストへ戻す。
final newlyUnlockedAchievementsProvider = StateProvider<List<Achievement>>((ref) {
  return [];
});

/// 実績判定(`AnalyticsService.checkAchievements`)・リーダーボード
/// (achievementsタイプ)反映・通知送信をまとめて行う。元は
/// `game_provider.dart`のAI対局終了フックにのみ存在していたため、PvP・
/// ブリッツ・通信対局・チーム対局・パズルラッシュでは実績が一切解除
/// されなかった（判定処理自体は呼ばれたことが無かった）。各ゲームモード
/// の対局終了箇所から共通して呼べるよう、ここに公開関数として配置する。
/// Best-effort: 呼び出し元の対局終了処理自体をブロックしない。
Future<void> checkAndRecordAchievementsAfterGame(Ref ref, String uid) async {
  try {
    final newlyUnlocked = await ref.read(checkAchievementsProvider(uid).future);
    if (newlyUnlocked.isEmpty) return;

    ref.read(newlyUnlockedAchievementsProvider.notifier).state = newlyUnlocked;

    final user = ref.read(currentUserProvider);
    final displayName = user?.displayName ?? 'Player';
    await ref.read(incrementUserStatsProvider)(
      uid: uid,
      displayName: displayName,
      type: LeaderboardType.achievements,
      achievementsUnlockedDelta: newlyUnlocked.length,
    );
    _logger.i('✅ ${newlyUnlocked.length} achievement(s) unlocked for $uid');

    for (final achievement in newlyUnlocked) {
      try {
        await ref.read(sendNotificationProvider)(
          uid: uid,
          title: '実績解除: ${achievement.name}',
          body: achievement.description,
          type: 'achievement',
          data: {'achievementId': achievement.id},
        );
      } catch (e) {
        _logger.w('実績通知送信失敗 (non-fatal): $e');
      }
    }
  } catch (e) {
    _logger.w('実績判定/リーダーボード反映失敗 (non-fatal): $e');
  }
}

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

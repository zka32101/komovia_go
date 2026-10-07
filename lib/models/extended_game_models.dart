import 'package:freezed_annotation/freezed_annotation.dart';

part 'extended_game_models.freezed.dart';
part 'extended_game_models.g.dart';

// ======================== Phase 69: Social Features ========================

/// Friend record
@freezed
abstract class Friend with _$Friend {
  const factory Friend({
    required String uid,
    required String displayName,
    required String status, // 'pending', 'accepted', 'blocked'
    required DateTime addedAt,
    String? notes,
    String? avatarUrl,
    // Who sent the original request - lets the UI tell an incoming request
    // (show accept/decline) apart from one this user sent themselves (show
    // cancel only). Nullable since relationship docs created before this
    // field existed don't have it; treated as "incoming" by callers when
    // absent, matching the pre-existing behavior for old data.
    String? requestedBy,
  }) = _Friend;

  factory Friend.fromJson(Map<String, dynamic> json) =>
      _$FriendFromJson(json);
}

/// Game invitation between players
@freezed
abstract class GameInvitation with _$GameInvitation {
  const factory GameInvitation({
    required String id,
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String gameMode, // currently always 'standard' (PvP)
    required int boardSize,
    required DateTime createdAt,
    required DateTime expiresAt,
    String? status, // 'pending', 'accepted', 'declined'
    String? customMessage,
  }) = _GameInvitation;

  factory GameInvitation.fromJson(Map<String, dynamic> json) =>
      _$GameInvitationFromJson(json);
}

/// Leaderboard entry
@freezed
abstract class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required String userId,
    required String displayName,
    required int rank,
    required double rating, // ELO or custom rating
    required int wins,
    required int losses,
    required int totalGames,
    required String period, // 'daily', 'weekly', 'monthly', 'allTime'
    @Default(0) double winRate,
    String? avatarUrl,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}

/// User profile extended
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String uid,
    required String displayName,
    String? avatarUrl,
    String? bio,
    @Default(0) int totalGamesPlayed,
    @Default(0) int totalWins,
    @Default([]) List<String> favoriteOpenings,
    @Default([]) List<String> achievements,
    @Default({}) Map<String, int> gameStats,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

// ======================== Phase 70: Game Modes Extension ========================

/// Handicap game settings (置き碁)
@freezed
abstract class HandicapSettings with _$HandicapSettings {
  const factory HandicapSettings({
    required int handicapStones, // 2-9
    String? komiAdjustment, // Custom komi value
    @Default([]) List<String> handicapPositions, // Hoshi positions
  }) = _HandicapSettings;

  factory HandicapSettings.fromJson(Map<String, dynamic> json) =>
      _$HandicapSettingsFromJson(json);
}

/// Reusable game preset
@freezed
abstract class GamePreset with _$GamePreset {
  const factory GamePreset({
    required String id,
    required String userId,
    required String name, // "My Favorite Setup"
    required String gameMode,
    required int boardSize,
    required int aiLevel,
    String? playerColor,
    HandicapSettings? handicap,
    required DateTime createdAt,
    @Default(0) int usageCount,
  }) = _GamePreset;

  factory GamePreset.fromJson(Map<String, dynamic> json) =>
      _$GamePresetFromJson(json);
}

// ======================== Phase 71: Analytics & Dashboard ========================

/// Game statistics
@freezed
abstract class GameStatistics with _$GameStatistics {
  const factory GameStatistics({
    required String userId,
    required int totalGamesPlayed,
    required int totalWins,
    required int totalLosses,
    required List<GameRecord> recentGames,
    @Default(0) double winRate,
    @Default(0) double averageGameDuration, // in minutes
    @Default('') String favoriteGameMode,
    @Default(0) int favoriteAiLevel,
    @Default('') String favoriteBoardSize,
    DateTime? lastPlayedAt,
    @Default({}) Map<String, dynamic> gamesByMode,
    @Default({}) Map<String, dynamic> gamesByLevel,
  }) = _GameStatistics;

  factory GameStatistics.fromJson(Map<String, dynamic> json) =>
      _$GameStatisticsFromJson(json);
}

/// Game record for statistics
@freezed
abstract class GameRecord with _$GameRecord {
  const factory GameRecord({
    required String gameId,
    required String result, // 'win', 'loss', 'draw'
    required double blackScore,
    required double whiteScore,
    required int boardSize,
    required int aiLevel,
    required String gameMode,
    required DateTime playedAt,
    required int durationSeconds,
    @Default(0) int moveCount,
  }) = _GameRecord;

  factory GameRecord.fromJson(Map<String, dynamic> json) =>
      _$GameRecordFromJson(json);
}

/// Achievement/Badge
@freezed
abstract class Achievement with _$Achievement {
  const factory Achievement({
    required String id,
    required String name,
    required String description,
    required String iconEmoji,
    @Default(false) bool isUnlocked,
    DateTime? unlockedAt,
    String? progressLabel, // "5 out of 10"
    @Default(0) double progressPercent,
  }) = _Achievement;

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);
}

/// Predefined achievements list
class PredefinedAchievements {
  static final List<Achievement> all = [
    Achievement(
      id: 'first_win',
      name: 'First Victory',
      description: 'Win your first game',
      iconEmoji: '🎉',
    ),
    Achievement(
      id: 'streak_5',
      name: 'Streak Master',
      description: 'Win 5 games in a row',
      iconEmoji: '🔥',
    ),
    Achievement(
      id: 'explorer',
      name: 'Explorer',
      description: 'Play all game modes',
      iconEmoji: '🗺️',
    ),
    Achievement(
      id: 'master_10',
      name: 'Master Level 10',
      description: 'Win 10 games at AI level 10',
      iconEmoji: '👑',
    ),
    Achievement(
      id: 'century',
      name: 'Century',
      description: 'Play 100 games',
      iconEmoji: '💯',
    ),
    Achievement(
      id: 'boardsize_collector',
      name: 'Board Size Collector',
      description: 'Play on all board sizes (9x9, 13x13, 19x19)',
      iconEmoji: '📐',
    ),
  ];
}

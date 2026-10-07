import 'package:freezed_annotation/freezed_annotation.dart';

part 'sns_models.freezed.dart';
part 'sns_models.g.dart';

// ===== Twitter/X Models =====

/// Response from posting a tweet
@freezed
abstract class TwitterTweetResponse with _$TwitterTweetResponse {
  const factory TwitterTweetResponse({
    required String tweetId,
    required String text,
    required DateTime createdAt,
    String? url,
  }) = _TwitterTweetResponse;

  factory TwitterTweetResponse.fromJson(Map<String, dynamic> json) =>
      _$TwitterTweetResponseFromJson(json);
}

/// Twitter metrics for engagement tracking
@freezed
abstract class TweetMetrics with _$TweetMetrics {
  const factory TweetMetrics({
    required String tweetId,
    required int likes,
    required int retweets,
    required int replies,
    required int quotes,
    required int impressions,
    required int bookmarks,
  }) = _TweetMetrics;

  factory TweetMetrics.fromJson(Map<String, dynamic> json) =>
      _$TweetMetricsFromJson(json);
}

// ===== Facebook Models =====

/// Response from posting to Facebook
@freezed
abstract class FacebookPostResponse with _$FacebookPostResponse {
  const factory FacebookPostResponse({
    required String postId,
    required String message,
    required DateTime createdAt,
    String? url,
  }) = _FacebookPostResponse;

  factory FacebookPostResponse.fromJson(Map<String, dynamic> json) =>
      _$FacebookPostResponseFromJson(json);
}

// ===== Game Mode Models =====

/// Represents a new game mode configuration
@freezed
abstract class GameMode with _$GameMode {
  const factory GameMode({
    required String id,
    required String name,
    required String description,
    required int timeLimit, // in seconds, 0 for no limit
    required String difficulty,
    required GameModeType type,
    required int maxPlayers,
    String? iconPath,
    @Default(false) bool isActive,
  }) = _GameMode;

  factory GameMode.fromJson(Map<String, dynamic> json) =>
      _$GameModeFromJson(json);
}

enum GameModeType {
  blitz('Blitz - 5分の高速対局'),
  correspondence('Correspondence - ターンベース対局'),
  team('Team Play - 2vs2チーム戦'),
  puzzleRush('Puzzle Rush - タイムアタック詰碁'),
  handicap('Handicap - ハンディキャップ戦'),
  traditional('Traditional - 標準対局');

  final String displayName;
  const GameModeType(this.displayName);
}

/// Active game session with mode info
@freezed
abstract class GameSession with _$GameSession {
  const factory GameSession({
    required String sessionId,
    required String gameId,
    required GameMode gameMode,
    required DateTime startedAt,
    DateTime? endedAt,
    required String blackPlayerId,
    required String whitePlayerId,
    @Default(0) int moveCount,
    @Default(300) int timeRemainingBlack,
    @Default(300) int timeRemainingWhite,
  }) = _GameSession;

  factory GameSession.fromJson(Map<String, dynamic> json) =>
      _$GameSessionFromJson(json);
}

/// Friend relationship in the app
@freezed
abstract class Friend with _$Friend {
  const factory Friend({
    required String userId,
    required String friendId,
    required String displayName,
    String? profileImageUrl,
    required DateTime addedAt,
    @Default(FriendStatus.pending) FriendStatus status,
  }) = _Friend;

  factory Friend.fromJson(Map<String, dynamic> json) =>
      _$FriendFromJson(json);
}

enum FriendStatus {
  pending('保留中'),
  accepted('承認済み'),
  blocked('ブロック中');

  final String displayName;
  const FriendStatus(this.displayName);
}

/// Game invitation to another player
@freezed
abstract class GameInvitation with _$GameInvitation {
  const factory GameInvitation({
    required String invitationId,
    required String fromUserId,
    required String toUserId,
    required GameMode gameMode,
    required DateTime createdAt,
    DateTime? respondedAt,
    @Default(InvitationStatus.pending) InvitationStatus status,
  }) = _GameInvitation;

  factory GameInvitation.fromJson(Map<String, dynamic> json) =>
      _$GameInvitationFromJson(json);
}

enum InvitationStatus {
  pending('保留中'),
  accepted('承認'),
  declined('拒否'),
  expired('期限切れ');

  final String displayName;
  const InvitationStatus(this.displayName);
}

/// Leaderboard entry
@freezed
abstract class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required String userId,
    required String displayName,
    required int rank,
    required int rating,
    required int gamesPlayed,
    required double winRate,
    String? profileImageUrl,
    @Default(LeaderboardScope.global) LeaderboardScope scope,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}

enum LeaderboardScope {
  global('グローバル'),
  monthly('月間'),
  seasonal('シーズン'),
  regional('地域別');

  final String displayName;
  const LeaderboardScope(this.displayName);
}

/// Tournament bracket structure
@freezed
abstract class Tournament with _$Tournament {
  const factory Tournament({
    required String tournamentId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int participantCount,
    @Default(TournamentStatus.upcoming) TournamentStatus status,
    @Default(TournamentFormat.singleElimination) TournamentFormat format,
    String? description,
  }) = _Tournament;

  factory Tournament.fromJson(Map<String, dynamic> json) =>
      _$TournamentFromJson(json);
}

enum TournamentStatus {
  upcoming('予定中'),
  active('進行中'),
  completed('完了');

  final String displayName;
  const TournamentStatus(this.displayName);
}

enum TournamentFormat {
  singleElimination('シングルエリミネーション'),
  doubleElimination('ダブルエリミネーション'),
  roundRobin('総当たり');

  final String displayName;
  const TournamentFormat(this.displayName);
}

/// Chat message during game observation
@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String messageId,
    required String fromUserId,
    required String fromDisplayName,
    required String content,
    required DateTime sentAt,
    String? gameId,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}

// ===== Share Attribution Models =====

/// Track SNS shares for attribution
@freezed
abstract class SocialShareTracking with _$SocialShareTracking {
  const factory SocialShareTracking({
    required String trackingId,
    required String userId,
    required String contentType, // 'game', 'puzzle', 'profile'
    required String contentId,
    required String platform, // 'twitter', 'facebook', 'whatsapp', 'line'
    required DateTime sharedAt,
    String? externalUrl,
  }) = _SocialShareTracking;

  factory SocialShareTracking.fromJson(Map<String, dynamic> json) =>
      _$SocialShareTrackingFromJson(json);
}

/// Share metrics for content analysis
@freezed
abstract class ShareMetrics with _$ShareMetrics {
  const factory ShareMetrics({
    required String contentId,
    required int twitterShares,
    required int facebookShares,
    required int whatsappShares,
    required int lineShares,
    required int totalShares,
    required int totalEngagement, // likes + retweets + comments
    @Default(0.0) double viralCoefficient,
  }) = _ShareMetrics;

  factory ShareMetrics.fromJson(Map<String, dynamic> json) =>
      _$ShareMetricsFromJson(json);
}

/// Social feature analytics
@freezed
abstract class SocialAnalytics with _$SocialAnalytics {
  const factory SocialAnalytics({
    required String userId,
    required int friendCount,
    required int gamesWithFriends,
    required int totalShares,
    required double avgEngagementPerShare,
    required DateTime lastActiveAt,
    @Default(0) int invitationsSent,
    @Default(0) int invitationsAccepted,
  }) = _SocialAnalytics;

  factory SocialAnalytics.fromJson(Map<String, dynamic> json) =>
      _$SocialAnalyticsFromJson(json);
}

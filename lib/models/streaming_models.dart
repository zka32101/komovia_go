import 'package:freezed_annotation/freezed_annotation.dart';

part 'streaming_models.freezed.dart';
part 'streaming_models.g.dart';

// ===== YouTube Models =====

/// YouTube ビデオ共有用データ
@freezed
abstract class YouTubeShareData with _$YouTubeShareData {
  const factory YouTubeShareData({
    required String userId,
    required String gameId,
    required String title,
    required String description,
    required List<int> moves, // Game moves sequence
    String? thumbnailUrl,
    String? channelId,
    @Default('unlisted') String visibility, // 'public', 'unlisted', 'private'
    @Default(false) bool autoGenerate,
  }) = _YouTubeShareData;

  factory YouTubeShareData.fromJson(Map<String, dynamic> json) =>
      _$YouTubeShareDataFromJson(json);
}

/// YouTube アップロード結果
@freezed
abstract class YouTubeUploadResult with _$YouTubeUploadResult {
  const factory YouTubeUploadResult({
    required String videoId,
    required String title,
    required String url,
    required DateTime uploadedAt,
    String? channelId,
    @Default('processing') String status, // 'processing', 'failed', 'completed'
  }) = _YouTubeUploadResult;

  factory YouTubeUploadResult.fromJson(Map<String, dynamic> json) =>
      _$YouTubeUploadResultFromJson(json);
}

// ===== Twitch Models =====

/// Twitch ストリーム設定
@freezed
abstract class TwitchStreamData with _$TwitchStreamData {
  const factory TwitchStreamData({
    required String userId,
    String? gameId, // 対局と紐付ける場合のみ設定（任意）
    required String streamTitle,
    required String category, // 'Board Games', etc
    @Default(false) bool isLive,
    String? channelId,
    String? streamUrl,
    @Default([]) List<String> tags,
    @Default(0) int viewerCount,
  }) = _TwitchStreamData;

  factory TwitchStreamData.fromJson(Map<String, dynamic> json) =>
      _$TwitchStreamDataFromJson(json);
}

/// Twitch ストリーム情報
@freezed
abstract class TwitchStreamInfo with _$TwitchStreamInfo {
  const factory TwitchStreamInfo({
    required String streamId,
    required String channelName,
    required String title,
    required DateTime startedAt,
    DateTime? endedAt,
    @Default(true) bool isLive,
    required int viewers,
    String? thumbnailUrl,
    String? category,
  }) = _TwitchStreamInfo;

  factory TwitchStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$TwitchStreamInfoFromJson(json);
}

// ===== AI Explanation Models =====

/// AI ゲーム解説
@freezed
abstract class AIExplanation with _$AIExplanation {
  const factory AIExplanation({
    required String id,
    required String gameId,
    required int moveNumber,
    required String explanation, // 日本語解説
    required String strategyTip,
    @Default([]) List<String> alternatives, // 代替手段
    @Default(0) double confidenceScore, // 0.0-1.0
    @Default('claude') String model, // 'claude' or 'gemini'
    required DateTime generatedAt,
  }) = _AIExplanation;

  factory AIExplanation.fromJson(Map<String, dynamic> json) =>
      _$AIExplanationFromJson(json);
}

/// AI 解説リクエスト
@freezed
abstract class ExplanationRequest with _$ExplanationRequest {
  const factory ExplanationRequest({
    required String gameId,
    required int moveNumber,
    required List<List<int>> boardState, // 碁盤の状態
    required String lastMove, // 最終手
    required String playerColor, // 'black' or 'white'
    @Default('comprehensive') String level, // 'quick', 'standard', 'comprehensive'
  }) = _ExplanationRequest;

  factory ExplanationRequest.fromJson(Map<String, dynamic> json) =>
      _$ExplanationRequestFromJson(json);
}

/// AI 解説チャット（リアルタイム）
@freezed
abstract class ExplanationChat with _$ExplanationChat {
  const factory ExplanationChat({
    required String id,
    required String gameId,
    required String role, // 'user' or 'assistant'
    required String message,
    required DateTime timestamp,
    @Default(false) bool isStreaming,
  }) = _ExplanationChat;

  factory ExplanationChat.fromJson(Map<String, dynamic> json) =>
      _$ExplanationChatFromJson(json);
}

// ===== Sponsorship Models =====

/// スポンサーシップレコード
@freezed
abstract class SponsorshipRecord with _$SponsorshipRecord {
  const factory SponsorshipRecord({
    required String id,
    required String sponsorUserId,
    required String sponsorDisplayName,
    required String sponsoredUserId,
    required String tierId,
    required String tierName,
    required int amountUSD, // Monthly sponsorship in USD cents
    required DateTime startDate,
    required DateTime? endDate,
    @Default('active') String status, // 'active', 'paused', 'cancelled'
    @Default('') String message, // Sponsor's message
    @Default([]) List<String> perks, // Special benefits
  }) = _SponsorshipRecord;

  factory SponsorshipRecord.fromJson(Map<String, dynamic> json) =>
      _$SponsorshipRecordFromJson(json);
}

/// スポンサー情報
@freezed
abstract class SponsorInfo with _$SponsorInfo {
  const factory SponsorInfo({
    required String userId,
    required String displayName,
    String? avatarUrl,
    @Default(0) int totalSponsorCount, // 本人がスポンサーしている数
    @Default(0) int totalSponsorshipCount, // 本人が受けているスポンサー数
    @Default(0) int totalMonthlyUSD, // Total monthly sponsorship income
    @Default([]) List<SponsorshipTier> availableTiers,
  }) = _SponsorInfo;

  factory SponsorInfo.fromJson(Map<String, dynamic> json) =>
      _$SponsorInfoFromJson(json);
}

/// スポンサーシップティア（段階）
@freezed
abstract class SponsorshipTier with _$SponsorshipTier {
  const factory SponsorshipTier({
    required String id,
    required String name, // '応援者', 'ファン', 'VIP応援者' など
    required int priceUSD, // Monthly price in USD cents
    required String description,
    @Default([]) List<String> benefits, // 特典リスト
    @Default(0) int maxSlots, // 0 = unlimited
    @Default(0) int currentSubscribers,
  }) = _SponsorshipTier;

  factory SponsorshipTier.fromJson(Map<String, dynamic> json) =>
      _$SponsorshipTierFromJson(json);
}

/// スポンサーシップ通知
@freezed
abstract class SponsorshipNotification with _$SponsorshipNotification {
  const factory SponsorshipNotification({
    required String id,
    required String recipientUserId,
    required String sponsorUserId,
    required String sponsorName,
    required int amountUSD,
    required String tier,
    @Default('new_sponsor') String type, // 'new_sponsor', 'tier_upgrade', 'renewal'
    required DateTime createdAt,
    @Default(false) bool isRead,
  }) = _SponsorshipNotification;

  factory SponsorshipNotification.fromJson(Map<String, dynamic> json) =>
      _$SponsorshipNotificationFromJson(json);
}

// ===== Combined Models =====

/// ゲーム配信情報（YouTube + Twitch 統合）
@freezed
abstract class GameStreamInfo with _$GameStreamInfo {
  const factory GameStreamInfo({
    required String gameId,
    String? youtubeVideoId,
    String? twitchStreamId,
    @Default([]) List<AIExplanation> explanations,
    @Default([]) List<SponsorshipNotification> sponsorNotifications,
    required DateTime createdAt,
  }) = _GameStreamInfo;

  factory GameStreamInfo.fromJson(Map<String, dynamic> json) =>
      _$GameStreamInfoFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'social_share_models.freezed.dart';
part 'social_share_models.g.dart';

/// Share data for a completed Go game
@freezed
abstract class GameShareData with _$GameShareData {
  const factory GameShareData({
    required String gameId,
    required String result, // 'win', 'loss', 'draw'
    required double blackScore,
    required double whiteScore,
    required int boardSize,
    required int aiLevel,
    @Default(false) bool includeImage,
    String? sgfUrl,
  }) = _GameShareData;

  factory GameShareData.fromJson(Map<String, dynamic> json) =>
      _$GameShareDataFromJson(json);
}

/// Share data for puzzle achievement
@freezed
abstract class PuzzleShareData with _$PuzzleShareData {
  const factory PuzzleShareData({
    required String puzzleId,
    required String difficulty, // 'easy', 'medium', 'hard', 'master'
    required int attemptCount,
    required Duration solvingTime,
    required bool isSolved,
    @Default(0) int currentStreak,
  }) = _PuzzleShareData;

  factory PuzzleShareData.fromJson(Map<String, dynamic> json) =>
      _$PuzzleShareDataFromJson(json);
}

/// Share data for user profile/progress
@freezed
abstract class ProfileShareData with _$ProfileShareData {
  const factory ProfileShareData({
    required String userId,
    required String displayName,
    @Default(0) int totalGamesPlayed,
    @Default(0) int winCount,
    @Default(0) int currentPuzzleStreak,
    @Default(0) int totalPuzzlesSolved,
    String? profileImageUrl,
  }) = _ProfileShareData;

  factory ProfileShareData.fromJson(Map<String, dynamic> json) =>
      _$ProfileShareDataFromJson(json);
}

/// Generated share content with text and metadata
@freezed
abstract class ShareContent with _$ShareContent {
  const factory ShareContent({
    required String text,
    required String hashtags,
    String? imageUrl,
    String? deepLink,
    @Default('GoEn') String appName,
  }) = _ShareContent;

  factory ShareContent.fromJson(Map<String, dynamic> json) =>
      _$ShareContentFromJson(json);
}

/// Social platform types
enum SocialPlatform {
  twitter('X (Twitter)'),
  facebook('Facebook'),
  whatsapp('WhatsApp'),
  line('LINE'),
  clipboard('Copy to Clipboard');

  final String displayName;
  const SocialPlatform(this.displayName);
}

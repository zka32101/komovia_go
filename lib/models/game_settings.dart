import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_settings.freezed.dart';

/// Blitz Game Settings
@freezed
abstract class BlitzGameSettings with _$BlitzGameSettings {
  const factory BlitzGameSettings({
    required String boardSize, // '9', '13', '19'
    required int aiLevel, // 1-10
    required String opponentType, // 'ai' or 'online'
    String? opponentUid,
  }) = _BlitzGameSettings;
}

/// Correspondence Game Settings
@freezed
abstract class CorrespondenceGameSettings with _$CorrespondenceGameSettings {
  const factory CorrespondenceGameSettings({
    required String boardSize,
    required String opponentUid,
    required String playerColor, // 'black' or 'white' or 'random'
    @Default(86400) int considerationTimeSeconds, // 24 hours default
  }) = _CorrespondenceGameSettings;
}

/// Team Game Settings
@freezed
abstract class TeamGameSettings with _$TeamGameSettings {
  const factory TeamGameSettings({
    required String boardSize,
    required List<String> team1Uids, // 2 players
    required List<String> team2Uids, // 2 players
  }) = _TeamGameSettings;
}

/// Puzzle Rush Settings
@freezed
abstract class PuzzleRushSettings with _$PuzzleRushSettings {
  const factory PuzzleRushSettings({
    required String difficulty, // 'easy', 'normal', 'hard', 'expert'
    @Default(300) int sessionSeconds, // 5 minutes
  }) = _PuzzleRushSettings;
}

/// Generic Game Settings State
@freezed
abstract class GameSettingsState with _$GameSettingsState {
  const factory GameSettingsState({
    BlitzGameSettings? blitzSettings,
    CorrespondenceGameSettings? correspondenceSettings,
    TeamGameSettings? teamSettings,
    PuzzleRushSettings? puzzleRushSettings,
    @Default(false) bool isLoading,
    String? error,
  }) = _GameSettingsState;
}

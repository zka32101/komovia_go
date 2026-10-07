import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_go/models/index.dart';

final _logger = Logger();

/// GameSettingsStorageService - 設定値の永続化管理
class GameSettingsStorageService {
  static const String _blitzBoardSizeKey = 'blitz_board_size';
  static const String _blitzAiLevelKey = 'blitz_ai_level';
  static const String _blitzOpponentTypeKey = 'blitz_opponent_type';

  static const String _correspondenceBoardSizeKey = 'correspondence_board_size';
  static const String _correspondenceOpponentUidKey =
      'correspondence_opponent_uid';
  static const String _correspondencePlayerColorKey =
      'correspondence_player_color';

  static const String _teamBoardSizeKey = 'team_board_size';
  static const String _teamTeam1UidsKey = 'team_team1_uids';
  static const String _teamTeam2UidsKey = 'team_team2_uids';

  static const String _puzzleRushDifficultyKey = 'puzzle_rush_difficulty';

  final SharedPreferences _prefs;

  GameSettingsStorageService({required SharedPreferences prefs})
    : _prefs = prefs;

  // ==================== Blitz Game Settings ====================

  /// Blitz game settings を保存
  Future<bool> saveBlitzSettings(BlitzGameSettings settings) async {
    try {
      _logger.i('Saving Blitz settings: $settings');
      await Future.wait([
        _prefs.setString(_blitzBoardSizeKey, settings.boardSize),
        _prefs.setInt(_blitzAiLevelKey, settings.aiLevel),
        _prefs.setString(_blitzOpponentTypeKey, settings.opponentType),
      ]);
      return true;
    } catch (e) {
      _logger.e('Error saving Blitz settings: $e');
      return false;
    }
  }

  /// Blitz game settings を読み込み
  BlitzGameSettings? loadBlitzSettings() {
    try {
      final boardSize = _prefs.getString(_blitzBoardSizeKey);
      if (boardSize == null) {
        return null;
      }

      final storedAiLevel = _prefs.getInt(_blitzAiLevelKey);
      if (storedAiLevel == null) {
        return null;
      }
      // A stored but out-of-range level (1-10) is treated as corrupted data
      // and falls back to a sane default, rather than discarding the record.
      final aiLevel = (storedAiLevel < 1 || storedAiLevel > 10)
          ? 5
          : storedAiLevel;
      final opponentType = _prefs.getString(_blitzOpponentTypeKey) ?? 'ai';

      final settings = BlitzGameSettings(
        boardSize: boardSize,
        aiLevel: aiLevel,
        opponentType: opponentType,
      );
      _logger.i('Loaded Blitz settings: $settings');
      return settings;
    } catch (e) {
      _logger.e('Error loading Blitz settings: $e');
      return null;
    }
  }

  // ==================== Correspondence Game Settings ====================

  /// Correspondence game settings を保存
  Future<bool> saveCorrespondenceSettings(
    CorrespondenceGameSettings settings,
  ) async {
    try {
      _logger.i('Saving Correspondence settings: $settings');
      await Future.wait([
        _prefs.setString(_correspondenceBoardSizeKey, settings.boardSize),
        _prefs.setString(_correspondenceOpponentUidKey, settings.opponentUid),
        _prefs.setString(_correspondencePlayerColorKey, settings.playerColor),
      ]);
      return true;
    } catch (e) {
      _logger.e('Error saving Correspondence settings: $e');
      return false;
    }
  }

  /// Correspondence game settings を読み込み
  CorrespondenceGameSettings? loadCorrespondenceSettings() {
    try {
      final boardSize = _prefs.getString(_correspondenceBoardSizeKey);
      final opponentUid = _prefs.getString(_correspondenceOpponentUidKey);
      final playerColor = _prefs.getString(_correspondencePlayerColorKey);

      if (boardSize == null ||
          opponentUid == null ||
          opponentUid.isEmpty ||
          playerColor == null) {
        return null;
      }

      final settings = CorrespondenceGameSettings(
        boardSize: boardSize,
        opponentUid: opponentUid,
        playerColor: playerColor,
      );
      _logger.i('Loaded Correspondence settings: $settings');
      return settings;
    } catch (e) {
      _logger.e('Error loading Correspondence settings: $e');
      return null;
    }
  }

  // ==================== Team Game Settings ====================

  /// Team game settings を保存
  Future<bool> saveTeamSettings(TeamGameSettings settings) async {
    try {
      _logger.i('Saving Team settings: $settings');
      await Future.wait([
        _prefs.setString(_teamBoardSizeKey, settings.boardSize),
        _prefs.setStringList(_teamTeam1UidsKey, settings.team1Uids),
        _prefs.setStringList(_teamTeam2UidsKey, settings.team2Uids),
      ]);
      return true;
    } catch (e) {
      _logger.e('Error saving Team settings: $e');
      return false;
    }
  }

  /// Team game settings を読み込み
  TeamGameSettings? loadTeamSettings() {
    try {
      final boardSize = _prefs.getString(_teamBoardSizeKey);

      if (boardSize == null) {
        return null;
      }

      final settings = TeamGameSettings(
        boardSize: boardSize,
        team1Uids: _prefs.getStringList(_teamTeam1UidsKey) ?? [],
        team2Uids: _prefs.getStringList(_teamTeam2UidsKey) ?? [],
      );
      _logger.i('Loaded Team settings: $settings');
      return settings;
    } catch (e) {
      _logger.e('Error loading Team settings: $e');
      return null;
    }
  }

  // ==================== Puzzle Rush Settings ====================

  /// Puzzle Rush settings を保存
  Future<bool> savePuzzleRushSettings(PuzzleRushSettings settings) async {
    try {
      _logger.i('Saving Puzzle Rush settings: $settings');
      await _prefs.setString(_puzzleRushDifficultyKey, settings.difficulty);
      return true;
    } catch (e) {
      _logger.e('Error saving Puzzle Rush settings: $e');
      return false;
    }
  }

  /// Puzzle Rush settings を読み込み
  PuzzleRushSettings? loadPuzzleRushSettings() {
    try {
      final difficulty = _prefs.getString(_puzzleRushDifficultyKey);

      if (difficulty == null) {
        return null;
      }

      final settings = PuzzleRushSettings(difficulty: difficulty);
      _logger.i('Loaded Puzzle Rush settings: $settings');
      return settings;
    } catch (e) {
      _logger.e('Error loading Puzzle Rush settings: $e');
      return null;
    }
  }

  // ==================== Clear All ====================

  /// 全設定をクリア
  Future<bool> clearAllSettings() async {
    try {
      _logger.i('Clearing all game settings');
      await Future.wait([
        _prefs.remove(_blitzBoardSizeKey),
        _prefs.remove(_blitzAiLevelKey),
        _prefs.remove(_blitzOpponentTypeKey),
        _prefs.remove(_correspondenceBoardSizeKey),
        _prefs.remove(_correspondenceOpponentUidKey),
        _prefs.remove(_correspondencePlayerColorKey),
        _prefs.remove(_teamBoardSizeKey),
        _prefs.remove(_teamTeam1UidsKey),
        _prefs.remove(_teamTeam2UidsKey),
        _prefs.remove(_puzzleRushDifficultyKey),
      ]);
      return true;
    } catch (e) {
      _logger.e('Error clearing settings: $e');
      return false;
    }
  }
}

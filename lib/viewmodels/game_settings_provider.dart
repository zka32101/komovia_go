import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

final _logger = Logger();

// ==================== Blitz Game Settings ====================

final blitzBoardSizeProvider = StateProvider<String>((ref) => '19');
final blitzAiLevelProvider = StateProvider<int>((ref) => 5);
final blitzOpponentTypeProvider = StateProvider<String>((ref) => 'ai');

final blitzGameSettingsProvider = Provider<BlitzGameSettings>((ref) {
  final boardSize = ref.watch(blitzBoardSizeProvider);
  final aiLevel = ref.watch(blitzAiLevelProvider);
  final opponentType = ref.watch(blitzOpponentTypeProvider);

  _logger.i('Blitz settings: $boardSize, Level $aiLevel, Type $opponentType');

  return BlitzGameSettings(
    boardSize: boardSize,
    aiLevel: aiLevel,
    opponentType: opponentType,
  );
});

final resetBlitzSettingsProvider = Provider<void>((ref) {
  ref.read(blitzBoardSizeProvider.notifier).state = '19';
  ref.read(blitzAiLevelProvider.notifier).state = 5;
  ref.read(blitzOpponentTypeProvider.notifier).state = 'ai';
});

// ==================== Correspondence Game Settings ====================

final correspondenceBoardSizeProvider = StateProvider<String>((ref) => '19');
final correspondenceOpponentUidProvider = StateProvider<String>((ref) => '');
final correspondencePlayerColorProvider =
    StateProvider<String>((ref) => 'random');

final correspondenceGameSettingsProvider =
    Provider<CorrespondenceGameSettings>((ref) {
  final boardSize = ref.watch(correspondenceBoardSizeProvider);
  final opponentUid = ref.watch(correspondenceOpponentUidProvider);
  final playerColor = ref.watch(correspondencePlayerColorProvider);

  _logger.i(
      'Correspondence settings: $boardSize, Opponent $opponentUid, Color $playerColor');

  return CorrespondenceGameSettings(
    boardSize: boardSize,
    opponentUid: opponentUid,
    playerColor: playerColor,
  );
});

final resetCorrespondenceSettingsProvider = Provider<void>((ref) {
  ref.read(correspondenceBoardSizeProvider.notifier).state = '19';
  ref.read(correspondenceOpponentUidProvider.notifier).state = '';
  ref.read(correspondencePlayerColorProvider.notifier).state = 'random';
});

// ==================== Team Game Settings ====================

final teamBoardSizeProvider = StateProvider<String>((ref) => '19');
final team1PlayersProvider = StateProvider<List<String>>((ref) => []);
final team2PlayersProvider = StateProvider<List<String>>((ref) => []);

final teamGameSettingsProvider = Provider<TeamGameSettings>((ref) {
  final boardSize = ref.watch(teamBoardSizeProvider);
  final team1 = ref.watch(team1PlayersProvider);
  final team2 = ref.watch(team2PlayersProvider);

  _logger.i('Team settings: $boardSize, Team1 ${team1.length}, Team2 ${team2.length}');

  return TeamGameSettings(
    boardSize: boardSize,
    team1Uids: team1,
    team2Uids: team2,
  );
});

final resetTeamSettingsProvider = Provider<void>((ref) {
  ref.read(teamBoardSizeProvider.notifier).state = '19';
  ref.read(team1PlayersProvider.notifier).state = [];
  ref.read(team2PlayersProvider.notifier).state = [];
});

// ==================== Puzzle Rush Settings ====================

final puzzleRushDifficultyProvider = StateProvider<String>((ref) => 'normal');

final puzzleRushSettingsProvider = Provider<PuzzleRushSettings>((ref) {
  final difficulty = ref.watch(puzzleRushDifficultyProvider);

  _logger.i('Puzzle Rush settings: $difficulty');

  return PuzzleRushSettings(
    difficulty: difficulty,
  );
});

final resetPuzzleRushSettingsProvider = Provider<void>((ref) {
  ref.read(puzzleRushDifficultyProvider.notifier).state = 'normal';
});

// ==================== Settings Validation ====================

final isBlitzSettingsValidProvider = Provider<bool>((ref) {
  final settings = ref.watch(blitzGameSettingsProvider);
  return settings.boardSize.isNotEmpty && settings.aiLevel > 0;
});

final isCorrespondenceSettingsValidProvider = Provider<bool>((ref) {
  final settings = ref.watch(correspondenceGameSettingsProvider);
  return settings.boardSize.isNotEmpty && settings.opponentUid.isNotEmpty;
});

final isTeamSettingsValidProvider = Provider<bool>((ref) {
  final settings = ref.watch(teamGameSettingsProvider);
  return settings.boardSize.isNotEmpty &&
      settings.team1Uids.length == 2 &&
      settings.team2Uids.length == 2;
});

final isPuzzleRushSettingsValidProvider = Provider<bool>((ref) {
  final settings = ref.watch(puzzleRushSettingsProvider);
  return settings.difficulty.isNotEmpty;
});

// ==================== Storage Service Integration ====================

/// SharedPreferences インスタンスプロバイダー
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// GameSettingsStorageService プロバイダー
final gameSettingsStorageServiceProvider = FutureProvider<GameSettingsStorageService>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return GameSettingsStorageService(prefs: prefs);
});

/// 保存済みのBlitzGameSettingsを読み込み
final loadBlitzSettingsProvider = FutureProvider<BlitzGameSettings?>((ref) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final settings = service.loadBlitzSettings();
    if (settings != null) {
      _logger.i('Loaded Blitz settings from storage: $settings');
      // UIプロバイダーを更新
      ref.read(blitzBoardSizeProvider.notifier).state = settings.boardSize;
      ref.read(blitzAiLevelProvider.notifier).state = settings.aiLevel;
      ref.read(blitzOpponentTypeProvider.notifier).state = settings.opponentType;
    }
    return settings;
  } catch (e) {
    _logger.e('Error loading Blitz settings: $e');
    return null;
  }
});

/// Blitzゲーム設定を保存
final saveBlitzSettingsProvider = FutureProvider.family<bool, BlitzGameSettings>((ref, settings) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final result = await service.saveBlitzSettings(settings);
    if (result) {
      _logger.i('Saved Blitz settings: $settings');
    }
    return result;
  } catch (e) {
    _logger.e('Error saving Blitz settings: $e');
    return false;
  }
});

/// 保存済みのCorrespondenceGameSettingsを読み込み
final loadCorrespondenceSettingsProvider = FutureProvider<CorrespondenceGameSettings?>((ref) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final settings = service.loadCorrespondenceSettings();
    if (settings != null) {
      _logger.i('Loaded Correspondence settings from storage: $settings');
      // UIプロバイダーを更新
      ref.read(correspondenceBoardSizeProvider.notifier).state = settings.boardSize;
      ref.read(correspondenceOpponentUidProvider.notifier).state = settings.opponentUid;
      ref.read(correspondencePlayerColorProvider.notifier).state = settings.playerColor;
    }
    return settings;
  } catch (e) {
    _logger.e('Error loading Correspondence settings: $e');
    return null;
  }
});

/// Correspondenceゲーム設定を保存
final saveCorrespondenceSettingsProvider = FutureProvider.family<bool, CorrespondenceGameSettings>((ref, settings) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final result = await service.saveCorrespondenceSettings(settings);
    if (result) {
      _logger.i('Saved Correspondence settings: $settings');
    }
    return result;
  } catch (e) {
    _logger.e('Error saving Correspondence settings: $e');
    return false;
  }
});

/// 保存済みのTeamGameSettingsを読み込み
final loadTeamSettingsProvider = FutureProvider<TeamGameSettings?>((ref) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final settings = service.loadTeamSettings();
    if (settings != null) {
      _logger.i('Loaded Team settings from storage: $settings');
      // UIプロバイダーを更新
      ref.read(teamBoardSizeProvider.notifier).state = settings.boardSize;
      ref.read(team1PlayersProvider.notifier).state = settings.team1Uids;
      ref.read(team2PlayersProvider.notifier).state = settings.team2Uids;
    }
    return settings;
  } catch (e) {
    _logger.e('Error loading Team settings: $e');
    return null;
  }
});

/// Teamゲーム設定を保存
final saveTeamSettingsProvider = FutureProvider.family<bool, TeamGameSettings>((ref, settings) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final result = await service.saveTeamSettings(settings);
    if (result) {
      _logger.i('Saved Team settings: $settings');
    }
    return result;
  } catch (e) {
    _logger.e('Error saving Team settings: $e');
    return false;
  }
});

/// 保存済みのPuzzleRushSettingsを読み込み
final loadPuzzleRushSettingsProvider = FutureProvider<PuzzleRushSettings?>((ref) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final settings = service.loadPuzzleRushSettings();
    if (settings != null) {
      _logger.i('Loaded Puzzle Rush settings from storage: $settings');
      // UIプロバイダーを更新
      ref.read(puzzleRushDifficultyProvider.notifier).state = settings.difficulty;
    }
    return settings;
  } catch (e) {
    _logger.e('Error loading Puzzle Rush settings: $e');
    return null;
  }
});

/// Puzzle Rushゲーム設定を保存
final savePuzzleRushSettingsProvider = FutureProvider.family<bool, PuzzleRushSettings>((ref, settings) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final result = await service.savePuzzleRushSettings(settings);
    if (result) {
      _logger.i('Saved Puzzle Rush settings: $settings');
    }
    return result;
  } catch (e) {
    _logger.e('Error saving Puzzle Rush settings: $e');
    return false;
  }
});

/// すべての設定をクリア
final clearAllSettingsProvider = FutureProvider<bool>((ref) async {
  try {
    final service = await ref.watch(gameSettingsStorageServiceProvider.future);
    final result = await service.clearAllSettings();
    if (result) {
      _logger.i('Cleared all settings');
      // UIプロバイダーをリセット
      ref.read(blitzBoardSizeProvider.notifier).state = '19';
      ref.read(blitzAiLevelProvider.notifier).state = 5;
      ref.read(blitzOpponentTypeProvider.notifier).state = 'ai';
      ref.read(correspondenceBoardSizeProvider.notifier).state = '19';
      ref.read(correspondenceOpponentUidProvider.notifier).state = '';
      ref.read(correspondencePlayerColorProvider.notifier).state = 'random';
      ref.read(teamBoardSizeProvider.notifier).state = '19';
      ref.read(team1PlayersProvider.notifier).state = [];
      ref.read(team2PlayersProvider.notifier).state = [];
      ref.read(puzzleRushDifficultyProvider.notifier).state = 'normal';
    }
    return result;
  } catch (e) {
    _logger.e('Error clearing settings: $e');
    return false;
  }
});

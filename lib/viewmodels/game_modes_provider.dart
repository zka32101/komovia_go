import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

// ============= Service Providers =============

/// Blitz ゲームサービスプロバイダー
final blitzGameServiceProvider = Provider<BlitzGameService>((ref) {
  return BlitzGameService();
});

/// Correspondence ゲームサービスプロバイダー
final correspondenceGameServiceProvider =
    Provider<CorrespondenceGameService>((ref) {
  return CorrespondenceGameService();
});

/// Team ゲームサービスプロバイダー
final teamGameServiceProvider = Provider<TeamGameService>((ref) {
  return TeamGameService();
});

/// Puzzle Rush サービスプロバイダー
final puzzleRushServiceProvider = Provider<PuzzleRushService>((ref) {
  return PuzzleRushService();
});

// ============= Blitz Game Providers =============

/// Blitz ゲーム開始プロバイダー
final startBlitzGameProvider = FutureProvider.family<BlitzGameRecord,
    ({String uid, int boardSize, String? aiLevel, String opponentUid})>((ref,
    params) async {
  _logger.i('Starting Blitz game with params: $params');
  final service = ref.watch(blitzGameServiceProvider);
  return service.startBlitzGame(
    uid: params.uid,
    boardSize: params.boardSize,
    aiLevel: params.aiLevel,
    opponentUid: params.opponentUid,
  );
});

/// Blitz ゲーム手追加プロバイダー。moveは対局ごと・着手ごとに異なる文字列
/// なので、FutureProvider.familyのキャッシュにすると対局が進むたびに
/// 際限なく増えてしまう(generateGameAnalysisProviderと同じ理由) -
/// 呼び出しの都度実行するプレーンなアクションにする。
final addBlitzMoveProvider = Provider<
    Future<void> Function({
      required String gameId,
      required String move,
      required String playerColor,
    })>((ref) {
  final service = ref.watch(blitzGameServiceProvider);
  return ({required gameId, required move, required playerColor}) async {
    _logger.i('Adding Blitz move: $move');
    return service.addMove(gameId: gameId, move: move, playerColor: playerColor);
  };
});

/// Blitz ゲーム終了プロバイダー。sgfDataは対局ごとに異なる長い文字列を
/// 含むため、同様にプレーンなアクションにする。
final endBlitzGameProvider = Provider<
    Future<BlitzGameRecord> Function({
      required String gameId,
      required String result,
      required String winnerColor,
      required String sgfData,
      required int ratingChange,
    })>((ref) {
  final service = ref.watch(blitzGameServiceProvider);
  return ({
    required gameId,
    required result,
    required winnerColor,
    required sgfData,
    required ratingChange,
  }) async {
    _logger.i('Ending Blitz game: $gameId');
    return service.endBlitzGame(
      gameId: gameId,
      result: result,
      winnerColor: winnerColor,
      sgfData: sgfData,
      ratingChange: ratingChange,
    );
  };
});

/// ユーザーの Blitz ゲーム履歴プロバイダー
final userBlitzHistoryProvider =
    FutureProvider.family<List<BlitzGameRecord>, String>((ref, uid) async {
  _logger.i('Fetching Blitz history for user: $uid');
  final service = ref.watch(blitzGameServiceProvider);
  return service.getUserBlitzHistory(uid: uid);
});

/// Blitz ゲーム統計プロバイダー
final blitzStatsProvider =
    FutureProvider.family<BlitzStats, String>((ref, uid) async {
  _logger.i('Fetching Blitz stats for user: $uid');
  final service = ref.watch(blitzGameServiceProvider);
  return service.getUserBlitzStats(uid: uid);
});

// ============= Correspondence Game Providers =============

/// Correspondence ゲーム開始プロバイダー
final startCorrespondenceGameProvider = FutureProvider.family<
    CorrespondenceGameRecord,
    ({String uid, String opponentUid, int boardSize})>((ref, params) async {
  _logger.i('Starting Correspondence game with params: $params');
  final service = ref.watch(correspondenceGameServiceProvider);
  return service.startCorrespondenceGame(
    uid: params.uid,
    opponentUid: params.opponentUid,
    boardSize: params.boardSize,
  );
});

/// Correspondence ゲーム手追加プロバイダー。addBlitzMoveProviderと同じ理由で
/// プレーンなアクションにする。
final addCorrespondenceMoveProvider = Provider<
    Future<void> Function({
      required String gameId,
      required String move,
      required String playerColor,
    })>((ref) {
  final service = ref.watch(correspondenceGameServiceProvider);
  return ({required gameId, required move, required playerColor}) async {
    _logger.i('Adding Correspondence move: $move');
    return service.addMoveToGame(gameId: gameId, move: move, playerColor: playerColor);
  };
});

/// Correspondence ゲーム終了プロバイダー。endBlitzGameProviderと同じ理由で
/// プレーンなアクションにする。
final endCorrespondenceGameProvider = Provider<
    Future<CorrespondenceGameRecord> Function({
      required String gameId,
      required String result,
      String? winnerColor,
      required String sgfData,
    })>((ref) {
  final service = ref.watch(correspondenceGameServiceProvider);
  return ({required gameId, required result, winnerColor, required sgfData}) async {
    _logger.i('Ending Correspondence game: $gameId');
    return service.endCorrespondenceGame(
      gameId: gameId,
      result: result,
      winnerColor: winnerColor,
      sgfData: sgfData,
    );
  };
});

/// Correspondence ゲーム放棄プロバイダー
final abandonCorrespondenceGameProvider =
    FutureProvider.family<void, String>((ref, gameId) async {
  _logger.i('Abandoning Correspondence game: $gameId');
  final service = ref.watch(correspondenceGameServiceProvider);
  return service.abandonGame(gameId: gameId);
});

/// ユーザーの Correspondence ゲーム一覧プロバイダー
final userCorrespondenceGamesProvider =
    FutureProvider.family<List<CorrespondenceGameRecord>, String>(
        (ref, uid) async {
  _logger.i('Fetching Correspondence games for user: $uid');
  final service = ref.watch(correspondenceGameServiceProvider);
  return service.getUserCorrespondenceGames(uid: uid);
});

/// 待機中の手の数プロバイダー
final pendingMoveCountProvider =
    FutureProvider.family<int, String>((ref, uid) async {
  _logger.i('Counting pending moves for user: $uid');
  final service = ref.watch(correspondenceGameServiceProvider);
  return service.getPendingMoveCount(uid: uid);
});

// ============= Team Game Providers =============

/// Team ゲーム開始プロバイダー
final startTeamGameProvider = FutureProvider.family<TeamGameRecord,
    ({List<String> team1Players, List<String> team2Players, int boardSize})>(
    (ref, params) async {
  _logger.i('Starting Team game with params: $params');
  final service = ref.watch(teamGameServiceProvider);
  return service.startTeamGame(
    team1Players: params.team1Players,
    team2Players: params.team2Players,
    boardSize: params.boardSize,
  );
});

/// 同じチーム編成の進行中のゲームがあれば再開し、無ければ新規作成する。
/// TeamGameScreenが開かれるたびにstartTeamGameProviderを直接呼んでいた
/// 以前の実装では、再度同じ画面を開くたびに新しい対局が作られてしまい、
/// 既存の進行中の対局に戻る方法が無かった（実バグ）。
final resumeOrStartTeamGameProvider = FutureProvider.family<TeamGameRecord,
    ({List<String> team1Players, List<String> team2Players, int boardSize})>(
    (ref, params) async {
  final service = ref.watch(teamGameServiceProvider);

  final existing = await service.findActiveTeamGame(
    team1Players: params.team1Players,
    team2Players: params.team2Players,
  );
  if (existing != null) {
    _logger.i('Resuming existing Team game: ${existing.id}');
    return existing;
  }

  _logger.i('Starting Team game with params: $params');
  return service.startTeamGame(
    team1Players: params.team1Players,
    team2Players: params.team2Players,
    boardSize: params.boardSize,
  );
});

/// Team ゲーム手追加プロバイダー。addBlitzMoveProviderと同じ理由でプレーンな
/// アクションにする。
final addTeamMoveProvider = Provider<
    Future<void> Function({
      required String gameId,
      required String move,
      required String playerColor,
    })>((ref) {
  final service = ref.watch(teamGameServiceProvider);
  return ({required gameId, required move, required playerColor}) async {
    _logger.i('Adding Team move: $move');
    return service.addMoveToTeamGame(gameId: gameId, move: move, playerColor: playerColor);
  };
});

/// Team ゲーム終了プロバイダー。endBlitzGameProviderと同じ理由でプレーンな
/// アクションにする。
final endTeamGameProvider = Provider<
    Future<TeamGameRecord> Function({
      required String gameId,
      required String result,
      required String sgfData,
    })>((ref) {
  final service = ref.watch(teamGameServiceProvider);
  return ({required gameId, required result, required sgfData}) async {
    _logger.i('Ending Team game: $gameId');
    return service.endTeamGame(gameId: gameId, result: result, sgfData: sgfData);
  };
});

/// プレイヤーの Team ゲーム一覧プロバイダー
final playerTeamGamesProvider =
    FutureProvider.family<List<TeamGameRecord>, String>((ref, uid) async {
  _logger.i('Fetching Team games for player: $uid');
  final service = ref.watch(teamGameServiceProvider);
  return service.getPlayerTeamGames(uid: uid);
});

/// Team ゲーム統計プロバイダー
final teamGameStatsProvider =
    FutureProvider.family<TeamGameStats, String>((ref, uid) async {
  _logger.i('Fetching Team game stats for player: $uid');
  final service = ref.watch(teamGameServiceProvider);
  return service.getTeamGameStats(uid: uid);
});

// ============= Puzzle Rush Providers =============

/// Puzzle Rush セッション開始プロバイダー
final startPuzzleRushProvider = FutureProvider.family<PuzzleRushRecord,
    ({String uid, String difficulty})>((ref, params) async {
  _logger.i('Starting Puzzle Rush session: difficulty=${params.difficulty}');
  final service = ref.watch(puzzleRushServiceProvider);
  return service.startPuzzleRush(
    uid: params.uid,
    difficulty: params.difficulty,
  );
});

/// パズル解答プロバイダー。addBlitzMoveProviderと同じ理由でプレーンな
/// アクションにする(puzzleIdが解答のたびに異なるため)。
final solvePuzzleProvider = Provider<
    Future<void> Function({
      required String sessionId,
      required String puzzleId,
      required int puzzleDifficulty,
      required bool isCorrect,
      required int solveTime,
    })>((ref) {
  final service = ref.watch(puzzleRushServiceProvider);
  return ({
    required sessionId,
    required puzzleId,
    required puzzleDifficulty,
    required isCorrect,
    required solveTime,
  }) async {
    _logger.i('Solving puzzle: $puzzleId');
    return service.solvePuzzle(
      sessionId: sessionId,
      puzzleId: puzzleId,
      puzzleDifficulty: puzzleDifficulty,
      isCorrect: isCorrect,
      solveTime: solveTime,
    );
  };
});

/// Puzzle Rush セッション終了プロバイダー。endBlitzGameProviderと同じ理由で
/// プレーンなアクションにする。
final endPuzzleRushProvider = Provider<
    Future<PuzzleRushRecord> Function({
      required String sessionId,
      String? displayName,
    })>((ref) {
  final service = ref.watch(puzzleRushServiceProvider);
  return ({required sessionId, displayName}) async {
    _logger.i('Ending Puzzle Rush session: $sessionId');
    return service.endPuzzleRush(sessionId: sessionId, displayName: displayName);
  };
});

/// ユーザーの Puzzle Rush 履歴プロバイダー
final userPuzzleRushHistoryProvider =
    FutureProvider.family<List<PuzzleRushRecord>, String>((ref, uid) async {
  _logger.i('Fetching Puzzle Rush history for user: $uid');
  final service = ref.watch(puzzleRushServiceProvider);
  return service.getUserPuzzleRushHistory(uid: uid);
});

/// Puzzle Rush 統計プロバイダー
final puzzleRushStatsProvider =
    FutureProvider.family<PuzzleRushStats, String>((ref, uid) async {
  _logger.i('Fetching Puzzle Rush stats for user: $uid');
  final service = ref.watch(puzzleRushServiceProvider);
  return service.getUserPuzzleRushStats(uid: uid);
});

/// Puzzle Rush リーダーボードプロバイダー
final puzzleRushLeaderboardProvider = FutureProvider.family<
    List<PuzzleRushLeaderboardEntry>,
    String>((ref, difficulty) async {
  _logger.i('Fetching Puzzle Rush leaderboard: difficulty=$difficulty');
  final service = ref.watch(puzzleRushServiceProvider);
  return service.getLeaderboard(difficulty: difficulty);
});

// ============= UI State Providers =============

/// ゲームモード UI 状態
class GameModeUIState {
  final bool isLoading;
  final String? selectedGameMode; // 'blitz', 'correspondence', 'team', 'puzzleRush'
  final String? errorMessage;
  final int currentStep; // ゲーム進行状況

  GameModeUIState({
    this.isLoading = false,
    this.selectedGameMode,
    this.errorMessage,
    this.currentStep = 0,
  });

  GameModeUIState copyWith({
    bool? isLoading,
    String? selectedGameMode,
    String? errorMessage,
    int? currentStep,
  }) {
    return GameModeUIState(
      isLoading: isLoading ?? this.isLoading,
      selectedGameMode: selectedGameMode ?? this.selectedGameMode,
      errorMessage: errorMessage ?? this.errorMessage,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  @override
  String toString() => 'GameModeUIState('
      'isLoading: $isLoading, '
      'selectedGameMode: $selectedGameMode, '
      'errorMessage: $errorMessage, '
      'currentStep: $currentStep)';
}

/// ゲームモード UI State Notifier
class GameModeUINotifier extends StateNotifier<GameModeUIState> {
  GameModeUINotifier() : super(GameModeUIState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void selectGameMode(String mode) {
    _logger.i('Selecting game mode: $mode');
    // copyWith uses `?? this.field`, which can't distinguish "explicitly
    // null" from "not provided" - construct directly to actually clear it.
    state = GameModeUIState(
      isLoading: state.isLoading,
      selectedGameMode: mode,
      errorMessage: null,
      currentStep: state.currentStep,
    );
  }

  void setError(String message) {
    _logger.e('Game mode error: $message');
    state = state.copyWith(errorMessage: message, isLoading: false);
  }

  void clearError() {
    state = GameModeUIState(
      isLoading: state.isLoading,
      selectedGameMode: state.selectedGameMode,
      errorMessage: null,
      currentStep: state.currentStep,
    );
  }

  void advanceStep(int newStep) {
    _logger.i('Advancing to step: $newStep');
    state = state.copyWith(currentStep: newStep);
  }

  void resetUI() {
    _logger.i('Resetting UI state');
    state = GameModeUIState();
  }
}

/// ゲームモード UI プロバイダー
final gameModeUIProvider =
    StateNotifierProvider<GameModeUINotifier, GameModeUIState>((ref) {
  return GameModeUINotifier();
});

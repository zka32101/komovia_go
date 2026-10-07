import 'dart:math';

import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/services/fuego_engine_service.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';
import 'package:komovia_go/viewmodels/fateful_move_provider.dart';
import 'package:komovia_go/viewmodels/concurrent_session_provider.dart';
import 'package:komovia_go/viewmodels/game_modes_analytics_provider.dart';
import 'package:komovia_go/viewmodels/leaderboard_provider.dart';
import 'package:komovia_go/viewmodels/position_echo_provider.dart';
import 'package:komovia_go/viewmodels/spectator_provider.dart';
import 'package:komovia_go/viewmodels/friend_activity_provider.dart';
import 'package:komovia_go/utils/sgf_parser.dart';
import 'package:komovia_go/utils/handicap_points.dart';

final _logger = Logger();

// ================== SERVICE PROVIDERS ==================

/// Singleton instance of Fuego AI Engine (On-device)
/// Lightweight, fast, offline-capable Go engine
final aiEngineServiceProvider = Provider<FuegoEngineService>((ref) {
  return FuegoEngineService();
});

/// Singleton instance of FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// ================== GAME STATE PROVIDERS ==================

/// Current game board state
/// Mutable state for live gameplay
final gameBoardStateProvider = StateProvider<BoardState>((ref) {
  return BoardState(
    boardSize: 9, // Default to 9x9
    stones: List.generate(9, (_) => List.filled(9, 0)),
    capturedBlack: 0,
    capturedWhite: 0,
    isBlackTurn: true,
  );
});

/// Current AI opponent difficulty (1-10)
final aiLevelProvider = StateProvider<int>((ref) {
  return 5; // Default to intermediate level
});

/// Number of moves played in current game
final movesCountProvider = StateProvider<int>((ref) {
  return 0;
});

/// Did the last player pass?
final lastPlayerPassedProvider = StateProvider<bool>((ref) {
  return false;
});

/// How many passes have been played in a row (resets to 0 the moment
/// either side places a stone). Two in a row ends the game.
final consecutivePassesProvider = StateProvider<int>((ref) {
  return 0;
});

/// Is the game currently active?
final isGameActiveProvider = StateProvider<bool>((ref) {
  return false;
});

/// Current game result (null if game in progress)
final gameResultProvider = StateProvider<GameEndResult?>((ref) {
  return null;
});

/// 縁機能: 現在の対局に紐づく観戦セッションID（ライブ観戦フレンド用）。
/// Set by startNewGameProvider once the spectator session is created,
/// cleared when the session is ended at game-record-save time.
final currentSpectatorSessionIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// 「対局を保存」で発行された実際のFirestore game ID。SNS共有はこのIDを
/// deepLinkに埋め込むため、保存前は必ずnull（GameResultScreenが仮の
/// タイムスタンプ等をgameIdとして共有してしまい、共有先でデータが
/// 引き継がれないバグを防ぐ)。startNewGameProviderで次の対局の開始時に
/// リセットされる。
final currentGameSavedIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// この対局についてすでに対局終了インタースティシャル広告を表示した
/// かどうか。GameResultScreenは何度も再ビルドされるため、これが無いと
/// 再ビルドのたびに広告を出そうとしてしまう。startNewGameProviderで
/// 次の対局の開始時にリセットされる。
final hasShownGameEndAdProvider = StateProvider<bool>((ref) {
  return false;
});

/// Resets all per-game state and marks the game active. This is the only
/// correct way to start a fresh game: the game state providers above are
/// plain (non-autoDispose) globals, so simply navigating to a new
/// AIGameScreen instance does **not** reset them — the previous game's
/// finished board, move count and pass counters would otherwise leak into
/// the next game (this is what "Play Again" used to do wrong).
///
/// `handicapStones` pre-places that many black stones on the standard star
/// points (see handicap_points.dart) and starts the game with white to
/// move, per the usual handicap-game convention. Note: the AI opponent's
/// scoring (judgeGameEndProvider, via FuegoEngineService) does not yet
/// support adjusting komi for a handicap game — this only implements the
/// stone placement/turn-order half of a handicap game.
final startNewGameProvider =
    Provider<void Function({int boardSize, int handicapStones})>((ref) {
  return ({int boardSize = 9, int handicapStones = 0}) {
    final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
    for (final point in handicapPoints(boardSize, handicapStones)) {
      stones[point.row][point.col] = 1; // black
    }
    ref.read(gameBoardStateProvider.notifier).state = BoardState(
      boardSize: boardSize,
      stones: stones,
      capturedBlack: 0,
      capturedWhite: 0,
      isBlackTurn: handicapStones < 2,
    );
    ref.invalidate(movesCountProvider);
    ref.invalidate(moveHistoryProvider);
    ref.invalidate(gameResultProvider);
    ref.invalidate(consecutivePassesProvider);
    ref.invalidate(lastPlayerPassedProvider);
    ref.invalidate(currentSpectatorSessionIdProvider);
    ref.invalidate(currentGameSavedIdProvider);
    ref.invalidate(hasShownGameEndAdProvider);
    ref.read(isGameActiveProvider.notifier).state = true;
    _logger.i('🆕 New game started');

    _startEnSessionTracking(ref);
  };
});

/// 縁機能: 対局開始を「同時刻の碁盤」に登録し、観戦セッションを開くことで
/// フレンドがライブ観戦できるようにする。Best-effort: failures are logged
/// and never block gameplay (no `await`, errors are caught and swallowed).
void _startEnSessionTracking(Ref ref) {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final boardSize = ref.read(gameBoardStateProvider).boardSize;
  final displayName = user.displayName ?? 'Player';

  () async {
    try {
      await ref.read(startPlaySessionProvider)(user.uid, displayName, boardSize, 'ai_game');
    } catch (e) {
      _logger.w('縁: play session start failed (non-fatal): $e');
    }
  }();

  () async {
    try {
      final session = await ref.read(createSpectatorSessionProvider)(
        DateTime.now().millisecondsSinceEpoch.toString(),
        'ai_game',
        user.uid,
        displayName,
        true,
        boardSize: boardSize,
      );
      ref.read(currentSpectatorSessionIdProvider.notifier).state = session.id;

      try {
        await ref.read(notifyFriendsOfLiveSessionProvider)(
          user.uid,
          displayName,
          session.id,
          'ai_game',
        );
      } catch (e) {
        _logger.w('縁: friend live-session notification failed (non-fatal): $e');
      }
    } catch (e) {
      _logger.w('縁: spectator session creation failed (non-fatal): $e');
    }
  }();
}

// ================== AI MOVE REQUESTS ==================

/// Request AI move from Fuego engine (On-device)
/// Fast (~200-400ms), offline-capable.
///
/// Returns null when it isn't the AI's turn yet. Reads (rather than
/// watches) board/level/move-count so this only recomputes when explicitly
/// invalidated by the caller after a legal player move — otherwise every
/// board mutation (including the AI's own move) would re-trigger a new
/// request and risk the AI racing against itself.
final aiMoveProvider = FutureProvider.autoDispose<AIMove?>((ref) async {
  final boardState = ref.read(gameBoardStateProvider);

  // The human always plays black in this screen; nothing to compute
  // until it's white's (the AI's) turn.
  if (boardState.isBlackTurn) {
    return null;
  }

  final aiLevel = ref.read(aiLevelProvider);
  final movesCount = ref.read(movesCountProvider);

  _logger.i('🎯 Fuego: AI move request (level=$aiLevel, size=${boardState.boardSize})');

  final aiEngine = ref.read(aiEngineServiceProvider);
  try {
    final aiMove = await aiEngine.requestAiMove(
      boardSize: boardState.boardSize,
      stones: boardState.stones,
      isPlayerBlack: true,
      aiLevel: aiLevel,
      movesCount: movesCount,
      koRow: boardState.koRow,
      koCol: boardState.koCol,
    );
    _logger.i('✅ Fuego response: $aiMove');
    return aiMove;
  } catch (e) {
    _logger.e('❌ Fuego request failed: $e');
    rethrow;
  }
});

// ================== GAME LOGIC ==================

/// Validate if a move is legal (client-side check): occupancy, suicide,
/// and simple ko, for whichever color's turn it currently is.
final validateMoveProvider = Provider.family<bool, ({int row, int col})>(
  (ref, params) {
    final boardState = ref.watch(gameBoardStateProvider);
    final aiEngine = ref.watch(aiEngineServiceProvider);
    final player = boardState.isBlackTurn ? 1 : 2;
    return aiEngine.validateMove(
      boardSize: boardState.boardSize,
      stones: boardState.stones,
      row: params.row,
      col: params.col,
      player: player,
      koRow: boardState.koRow,
      koCol: boardState.koCol,
    );
  },
);

/// Attempts to play a stone at (row, col) for whichever color's turn it
/// currently is. On success, applies captures, flips the turn, updates the
/// ko point, records history, and returns true. Returns false (without any
/// state change) if the move is illegal.
final applyMoveProvider = Provider<bool Function(int row, int col)>((ref) {
  return (row, col) {
    final board = ref.read(gameBoardStateProvider);
    final player = board.isBlackTurn ? 1 : 2;

    final result = GoRules.applyMove(
      stones: board.stones,
      boardSize: board.boardSize,
      row: row,
      col: col,
      player: player,
      koRow: board.koRow,
      koCol: board.koCol,
    );

    if (result == null) {
      _logger.w('Illegal move rejected: player=$player [$row,$col]');
      return false;
    }

    ref.read(gameBoardStateProvider.notifier).state = board.copyWith(
      stones: result.stones,
      capturedBlack: player == 2 ? board.capturedBlack + result.capturedCount : null,
      capturedWhite: player == 1 ? board.capturedWhite + result.capturedCount : null,
      isBlackTurn: !board.isBlackTurn,
      lastMoveRow: row,
      lastMoveCol: col,
      koRow: result.koRow,
      koCol: result.koCol,
    );

    ref.read(addMoveProvider)(row, col, player == 1 ? 'black' : 'white');

    // A real move breaks any run of passes.
    ref.read(consecutivePassesProvider.notifier).state = 0;
    ref.read(lastPlayerPassedProvider.notifier).state = false;

    _logger.i(
      '✅ Move applied: player=$player [$row,$col] captured=${result.capturedCount}',
    );

    // 縁機能: この一手が「運命の一手」（大石を仕留めた・劫を制した等）に
    // 当たるか検出し、該当すればフレンドにシェアする。Player's move only —
    // the AI's own captures aren't the human player's "fateful moment".
    if (player == 1 && result.capturedCount > 0) {
      _detectFatefulMove(ref, result.capturedCount, board.koRow != null);
    }

    // 縁機能: ライブ観戦フレンドが盤面をリアルタイムで見られるよう、
    // 開いている観戦セッションがあれば毎手同期する。
    _syncSpectatorBoard(ref, row, col);

    return true;
  };
});

/// 縁機能: best-effort spectator board sync; never blocks gameplay.
void _syncSpectatorBoard(Ref ref, int lastMoveRow, int lastMoveCol) {
  final sessionId = ref.read(currentSpectatorSessionIdProvider);
  if (sessionId == null) return;

  final board = ref.read(gameBoardStateProvider);
  final movesCount = ref.read(movesCountProvider);

  () async {
    try {
      await ref.read(updateSpectatorBoardStateProvider)(
        sessionId,
        movesCount,
        board.stones,
        board.isBlackTurn,
        lastMoveRow,
        lastMoveCol,
      );
    } catch (e) {
      _logger.w('縁: spectator board sync failed (non-fatal): $e');
    }
  }();
}

/// 縁機能: best-effort fateful-move detection; never blocks gameplay.
void _detectFatefulMove(Ref ref, int capturedCount, bool wasKoResolved) {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final movesCount = ref.read(movesCountProvider);
  final boardSize = ref.read(gameBoardStateProvider).boardSize;
  final displayName = user.displayName ?? 'Player';

  () async {
    try {
      await ref.read(detectAndShareFatefulMoveProvider)(
        user.uid,
        displayName,
        null,
        movesCount,
        boardSize,
        capturedCount,
        wasKoResolved,
      );
    } catch (e) {
      _logger.w('縁: fateful move detection failed (non-fatal): $e');
    }
  }();
}

/// Passes for whichever color's turn it currently is: flips the turn,
/// clears any ko restriction, and increments the consecutive-pass count.
/// Returns true when this was the second consecutive pass, meaning the
/// game has now ended.
final applyPassProvider = Provider<bool Function()>((ref) {
  return () {
    final board = ref.read(gameBoardStateProvider);
    final player = board.isBlackTurn ? 1 : 2;

    ref.read(gameBoardStateProvider.notifier).state = board.copyWith(
      isBlackTurn: !board.isBlackTurn,
      koRow: null,
      koCol: null,
    );

    // Record the pass in move history (but NOT via addMoveProvider, since
    // that also increments movesCountProvider — a pass isn't a stone
    // placement) so it's preserved in the saved SGF instead of silently
    // vanishing from a game's move sequence. row/col -1 marks a pass; see
    // generateSgfFromMoves.
    final history = ref.read(moveHistoryProvider);
    ref.read(moveHistoryProvider.notifier).state = [
      ...history,
      (row: -1, col: -1, player: player == 1 ? 'black' : 'white'),
    ];

    ref.read(lastPlayerPassedProvider.notifier).state = true;
    final passes = ref.read(consecutivePassesProvider.notifier).state + 1;
    ref.read(consecutivePassesProvider.notifier).state = passes;

    _logger.i('Pass: player=$player consecutivePasses=$passes');
    return passes >= 2;
  };
});

/// Judge if game has ended and calculate score (Fuego).
/// Only runs when explicitly read/invalidated (e.g. after both players
/// pass) — it does not watch board state, since that would re-run scoring
/// on every single stone placed.
final judgeGameEndProvider = FutureProvider.autoDispose<GameEndResult>((ref) async {
  final boardState = ref.read(gameBoardStateProvider);
  final lastPlayerPassed = ref.read(lastPlayerPassedProvider);

  _logger.i('🏁 Fuego: Game end judgment (size=${boardState.boardSize})');

  final aiEngine = ref.read(aiEngineServiceProvider);
  try {
    final result = await aiEngine.judgeGameEnd(
      boardSize: boardState.boardSize,
      stones: boardState.stones,
      isPlayerBlack: true,
      lastPlayerPassed: lastPlayerPassed,
    );
    _logger.i('✅ Fuego judgment: $result');
    return result;
  } catch (e) {
    _logger.e('❌ Fuego judgment failed: $e');
    rethrow;
  }
});

// ================== MOVE HISTORY ==================

/// Stores the sequence of moves in the current game
/// Used for SGF generation and replay
final moveHistoryProvider = StateProvider<List<({int row, int col, String player})>>((ref) {
  return [];
});

/// Add move to history and update board state
final addMoveProvider = Provider<void Function(int, int, String)>((ref) {
  return (row, col, player) {
    _logger.i('Adding move: $player at [$row, $col]');

    final history = ref.read(moveHistoryProvider);
    ref.read(moveHistoryProvider.notifier).state = [
      ...history,
      (row: row, col: col, player: player),
    ];

    // Update moves count
    ref.read(movesCountProvider.notifier).state++;

    _logger.i('✅ Move added to history');
  };
});

// ================== GAME RECORD SAVING ==================

/// Save the just-finished game to Firestore.
///
/// This is a plain action (like [applyMoveProvider]/[applyPassProvider]),
/// not a `FutureProvider.family` — a family provider caches by its
/// argument value, so two different games with the same
/// (uid, boardSize, result) tuple (e.g. two 9x9 wins in a row) would
/// collide and the second "Save Game" tap would silently return the
/// first game's cached result instead of writing the new one.
final saveGameRecordProvider = Provider<
    Future<String> Function({
      required String uid,
      required int boardSize,
      required String result,
      double? blackScore,
      double? whiteScore,
    })>((ref) {
  return ({
    required uid,
    required boardSize,
    required result,
    blackScore,
    whiteScore,
  }) async {
    _logger.i('Saving game record for user: $uid');

    final boardState = ref.read(gameBoardStateProvider);
    final aiLevel = ref.read(aiLevelProvider);
    final movesCount = ref.read(movesCountProvider);

    // Real move-order SGF (see sgf_parser.dart), not boardState.toSgf()'s
    // final-snapshot-only dialect — this is what lets GameHistoryScreen
    // show an actual move-by-move replay instead of just the end position.
    final sgfData = generateSgfFromMoves(ref.read(moveHistoryProvider), boardSize);

    final gameRecord = GameRecord(
      id: '', // Firestore will auto-generate
      uid: uid,
      boardSize: boardSize,
      sgfData: sgfData,
      result: _parseResult(result),
      aiLevel: aiLevel,
      playedAt: DateTime.now(),
      movesCount: movesCount,
      gameDuration: Duration.zero, // TBD: track actual duration
      blackScore: blackScore,
      whiteScore: whiteScore,
    );

    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      final gameId = await firestoreService.saveGameRecord(gameRecord);
      _logger.i('✅ Game record saved: $gameId');

      _finalizeEnSession(ref, uid, boardState, movesCount);
      _updateAiGameRating(ref, uid, gameRecord.result, aiLevel);
      _checkAndRecordAchievements(ref, uid);

      return gameId;
    } catch (e) {
      _logger.e('❌ Game record save failed: $e');
      rethrow;
    }
  };
});

/// 縁機能: ゲーム終了時に局面の轍を記録し、「同時刻の碁盤」「ライブ観戦
/// フレンド」のセッションを閉じる。Best-effort: never blocks the (already
/// successful) game-record save.
void _finalizeEnSession(Ref ref, String uid, BoardState boardState, int movesCount) {
  final user = ref.read(currentUserProvider);
  final displayName = user?.displayName ?? 'Player';

  () async {
    try {
      await ref.read(recordPositionReachedProvider)(uid, displayName, boardState, movesCount);
    } catch (e) {
      _logger.w('縁: position echo recording failed (non-fatal): $e');
    }
  }();

  () async {
    try {
      await ref.read(endPlaySessionProvider)(uid);
    } catch (e) {
      _logger.w('縁: play session end failed (non-fatal): $e');
    }
  }();

  final sessionId = ref.read(currentSpectatorSessionIdProvider);
  if (sessionId != null) {
    () async {
      try {
        await ref.read(endSpectatorSessionProvider)(sessionId);
      } catch (e) {
        _logger.w('縁: spectator session end failed (non-fatal): $e');
      }
    }();
    ref.read(currentSpectatorSessionIdProvider.notifier).state = null;
  }
}

/// AI対局の結果をリーダーボード(ratingタイプ)に反映する。
///
/// LeaderboardType.rating の宣言コメント「ELO Rating (AI games)」が示す
/// 本来の意図(PvP実装時にはAI対局側の反映は未着手だった)。AIレベル
/// (1-10)を仮想レーティング(1000+level*100)とみなし、標準Elo式で
/// プレイヤーのレーティングを更新する — pvp_game_provider.dart の
/// _updateEloRatings と同じ考え方だが、AI相手は対人戦ほど変動の重みを
/// 持たせるべきではないためK factorを24に抑えている(PvPはK=32)。
/// Best-effort: never blocks the (already successful) game-record save.
void _updateAiGameRating(Ref ref, String uid, GameResult result, int aiLevel) {
  final double playerScore;
  switch (result) {
    case GameResult.playerWin:
      playerScore = 1.0;
      break;
    case GameResult.aiWin:
    case GameResult.resignation:
      playerScore = 0.0;
      break;
    case GameResult.draw:
    case GameResult.unknown:
      playerScore = 0.5;
      break;
  }

  () async {
    try {
      final user = ref.read(currentUserProvider);
      final displayName = user?.displayName ?? 'Player';
      final leaderboardService = ref.read(leaderboardServiceProvider);
      final entry = await leaderboardService.getUserRank(
        uid: uid,
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
      );
      final currentRating = entry?.rating ?? 1200;
      final aiVirtualRating = 1000 + aiLevel * 100;

      const kFactor = 24;
      final expected =
          1.0 / (1.0 + pow(10, (aiVirtualRating - currentRating) / 400));
      final newRating = (currentRating + kFactor * (playerScore - expected)).round();

      await ref.read(incrementUserStatsProvider)(
        uid: uid,
        displayName: displayName,
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
        newRating: newRating,
        gamesPlayedDelta: 1,
        winsDelta: playerScore == 1.0 ? 1 : 0,
      );
    } catch (e) {
      _logger.w('AI対局のレーティング反映失敗 (non-fatal): $e');
    }
  }();
}

/// AnalyticsService.checkAchievements（新規解除された実績の判定・
/// users/{uid}/achievements への保存）は、AnalyticsDashboardScreen の
/// 表示側（unlockedAchievementsProvider＝解除済みを読むだけ）からは
/// 一度も呼ばれておらず、対局終了時のフックも存在しなかったため、実績が
/// 実際に解除される経路がアプリのどこにも無かった。ここで対局終了の
/// たびに判定を走らせ、新規解除分をリーダーボード(achievementsタイプ)
/// にも反映する。newlyUnlockedAchievementsProviderにも書き込み、
/// GameResultScreenが対局結果画面上でトースト表示できるようにする
/// （それまでは実績が解除されてもAnalyticsDashboardScreenを自分から
/// 開かない限り気づけなかった）。Best-effort: never blocks the
/// (already successful) game-record save.
void _checkAndRecordAchievements(Ref ref, String uid) {
  () async {
    try {
      final newlyUnlocked =
          await ref.read(checkAchievementsProvider(uid).future);
      if (newlyUnlocked.isEmpty) return;

      ref.read(newlyUnlockedAchievementsProvider.notifier).state = newlyUnlocked;

      final user = ref.read(currentUserProvider);
      final displayName = user?.displayName ?? 'Player';
      await ref.read(incrementUserStatsProvider)(
        uid: uid,
        displayName: displayName,
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.achievements,
        achievementsUnlockedDelta: newlyUnlocked.length,
      );
      _logger.i('✅ ${newlyUnlocked.length} achievement(s) unlocked for $uid');
    } catch (e) {
      _logger.w('実績判定/リーダーボード反映失敗 (non-fatal): $e');
    }
  }();
}

/// Helper: parse result string to GameResult enum
GameResult _parseResult(String result) {
  switch (result.toLowerCase()) {
    case 'win':
    case 'playerwin':
      return GameResult.playerWin;
    case 'lose':
    case 'aiwin':
      return GameResult.aiWin;
    case 'draw':
      return GameResult.draw;
    case 'resign':
    case 'resignation':
      return GameResult.resignation;
    default:
      return GameResult.unknown;
  }
}

// ================== GAME HISTORY ==================

/// Get user's game records (paginated)
final userGameRecordsProvider = FutureProvider.family<List<GameRecord>, String>(
  (ref, uid) async {
    _logger.i('Fetching game records for user: $uid');

    final firestoreService = ref.watch(firestoreServiceProvider);
    try {
      final records = await firestoreService.getUserGameRecords(uid, limit: 20);
      _logger.i('✅ Game records fetched: ${records.length}');
      return records;
    } catch (e) {
      _logger.e('❌ Failed to fetch game records: $e');
      rethrow;
    }
  },
);

/// Get specific game record by ID
final gameRecordProvider = FutureProvider.family<GameRecord?, String>(
  (ref, gameId) async {
    _logger.i('Fetching game record: $gameId');

    final firestoreService = ref.watch(firestoreServiceProvider);
    try {
      final record = await firestoreService.getGameRecord(gameId);
      _logger.i('✅ Game record fetched: $gameId');
      return record;
    } catch (e) {
      _logger.e('❌ Failed to fetch game record: $e');
      rethrow;
    }
  },
);

// ================== POSITION EVALUATION ==================

/// Evaluate current board position (形勢評価)
/// Returns score difference and assessment
final positionEvaluationProvider = FutureProvider.autoDispose<({double scoreDiff, String assessment, double blackWinProb})>((ref) async {
  final boardState = ref.watch(gameBoardStateProvider);

  _logger.i('📊 Position evaluation request (size=${boardState.boardSize})');

  final aiEngine = ref.watch(aiEngineServiceProvider);
  try {
    final evaluation = await aiEngine.evaluatePosition(
      stones: boardState.stones,
      boardSize: boardState.boardSize,
    );
    _logger.i('✅ Evaluation: ${evaluation.assessment}');

    return (
      scoreDiff: evaluation.scoreDiff,
      assessment: evaluation.assessment,
      blackWinProb: evaluation.blackWinProbability,
    );
  } catch (e) {
    _logger.e('❌ Evaluation failed: $e');
    rethrow;
  }
});

// ================== AI OPPONENT CONFIG ==================

/// Selected AI opponent configuration
final selectedAiConfigProvider = StateProvider<AIOpponentConfig>((ref) {
  return AIOpponentConfig.intermediate();
});

/// Switch AI difficulty preset
final setAiConfigProvider = Provider<void Function(AIOpponentConfig)>((ref) {
  return (config) {
    _logger.i('Switching AI config: level ${config.level}');
    ref.read(selectedAiConfigProvider.notifier).state = config;
    ref.read(aiLevelProvider.notifier).state = config.level;
  };
});

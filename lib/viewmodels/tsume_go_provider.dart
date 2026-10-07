import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/models/leaderboard.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';

final _logger = Logger();

// ================== TODAY'S PUZZLE ==================

/// Singleton instance of FirestoreService (shared with game_provider)
final tsumeGoFirestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Today's daily tsume-go problem
/// Deterministic: same problem for all users on same day
final todaysTsumeProblemProvider = FutureProvider<TsumeGoProblem?>((ref) async {
  _logger.i('Fetching today\'s tsume-go problem');

  final firestoreService = ref.watch(tsumeGoFirestoreProvider);
  try {
    final problem = await firestoreService.getTodaysTsumeProblem();
    _logger.i('✅ Today\'s problem fetched: ${problem?.id ?? 'none'}');
    return problem;
  } catch (e) {
    _logger.e('❌ Failed to fetch today\'s problem: $e');
    rethrow;
  }
});

// ================== TSUME-GO PUZZLE STATE ==================

/// Current puzzle being solved (can override today's default)
///
/// NOTE: this `ref.watch`s todaysTsumeProblemProvider so its state
/// rebuilds (silently discarding any explicit selection made via
/// loadPuzzleProvider) whenever that FutureProvider is re-evaluated —
/// currently harmless since nothing in the app ever invalidates
/// todaysTsumeProblemProvider (loadPuzzleProvider/
/// tsumeProblemesByDifficultyProvider, the only other-difficulty pickers,
/// have no UI caller either). If either of those is ever wired up, this
/// will need a one-time-sync-then-independent pattern instead of a plain
/// watch.
final currentTsumeProblemProvider = StateProvider<TsumeGoProblem?>((ref) {
  // Initialize with today's problem
  final todaysProblem = ref.watch(todaysTsumeProblemProvider);
  return todaysProblem.value;
});

/// Current puzzle solution attempt, initialized from the problem's
/// starting position (parsed from its SGF setup).
final currentPuzzleBoardProvider = StateProvider<BoardState>((ref) {
  final problem = ref.watch(currentTsumeProblemProvider);
  if (problem == null) {
    return BoardState.empty(size: 9);
  }
  return BoardState.fromSgf(problem.sgfData);
});

/// Is current puzzle solved?
final isPuzzleSolvedProvider = StateProvider<bool>((ref) {
  return false;
});

/// Number of attempts on current puzzle
final puzzleAttemptCountProvider = StateProvider<int>((ref) {
  return 0;
});

/// Time spent on current puzzle (in seconds)
final puzzleSolvingTimeProvider = StateProvider<int>((ref) {
  return 0;
});

/// Attempts to place a stone on the puzzle board (the player always plays
/// black, same convention as AI games). Reuses the live-game capture/
/// suicide/ko rules. Returns true if the move was legal and applied.
final applyPuzzleMoveProvider = Provider<bool Function(int row, int col)>((ref) {
  return (row, col) {
    final board = ref.read(currentPuzzleBoardProvider);
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

    if (result == null) return false;

    ref.read(currentPuzzleBoardProvider.notifier).state = board.copyWith(
      stones: result.stones,
      isBlackTurn: !board.isBlackTurn,
      lastMoveRow: row,
      lastMoveCol: col,
      koRow: result.koRow,
      koCol: result.koCol,
    );
    return true;
  };
});

/// Resets the puzzle board back to the problem's initial setup position.
final resetPuzzleBoardProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(currentPuzzleBoardProvider);
});

// ================== PUZZLE ACTIONS ==================

/// Load a specific puzzle by ID
final loadPuzzleProvider = FutureProvider.family<TsumeGoProblem?, String>(
  (ref, problemId) async {
    _logger.i('Loading puzzle: $problemId');

    final firestoreService = ref.watch(tsumeGoFirestoreProvider);
    try {
      final problem = await firestoreService.getTsumeProblem(problemId);
      if (problem != null) {
        ref.read(currentTsumeProblemProvider.notifier).state = problem;
        ref.read(isPuzzleSolvedProvider.notifier).state = false;
        ref.read(puzzleAttemptCountProvider.notifier).state = 0;
        _logger.i('✅ Puzzle loaded: $problemId');
      }
      return problem;
    } catch (e) {
      _logger.e('❌ Failed to load puzzle: $e');
      rethrow;
    }
  },
);

/// Get puzzles by difficulty level
final tsumeProblemesByDifficultyProvider =
    FutureProvider.family<List<TsumeGoProblem>, int>(
  (ref, difficulty) async {
    _logger.i('Fetching tsume-go problems: difficulty=$difficulty');

    final firestoreService = ref.watch(tsumeGoFirestoreProvider);
    try {
      final problems = await firestoreService.getTsumeProblems(difficulty, limit: 10);
      _logger.i('✅ Problems fetched: ${problems.length}');
      return problems;
    } catch (e) {
      _logger.e('❌ Failed to fetch problems: $e');
      rethrow;
    }
  },
);

/// Check if puzzle solution is correct
/// Returns true if user's solution matches expected solution
///
/// Both sides are this app's own SGF dialect (see [BoardState.toSgf]): a
/// full board snapshot (every stone, not just the moves played), not a
/// move sequence. `userSolutionSgf` comes from the live puzzle board's
/// toSgf(), and [TsumeGoProblem.solutionSgf] is expected to be a snapshot
/// of the same final position. Comparing stone grids rather than raw
/// strings avoids depending on toSgf()'s row-major write order matching
/// byte-for-byte.
final checkPuzzleSolutionProvider = Provider.family<bool, String>(
  (ref, userSolutionSgf) {
    final problem = ref.watch(currentTsumeProblemProvider);
    if (problem == null) {
      return false;
    }

    _logger.i('Checking puzzle solution...');
    final userBoard = BoardState.fromSgf(userSolutionSgf);
    final solutionBoard = BoardState.fromSgf(problem.solutionSgf);
    if (userBoard.boardSize != solutionBoard.boardSize) return false;
    for (var row = 0; row < userBoard.boardSize; row++) {
      for (var col = 0; col < userBoard.boardSize; col++) {
        if (userBoard.stones[row][col] != solutionBoard.stones[row][col]) {
          return false;
        }
      }
    }
    return true;
  },
);

/// Records an attempt at the current puzzle.
///
/// This is a plain action (like [applyPuzzleMoveProvider]), not a
/// `FutureProvider.family` — a family provider caches by its argument
/// value, so two attempts with the same (uid, isCorrect, sgf) tuple would
/// collide and the second call would return the first attempt's cached
/// Firestore write instead of actually recording the new one (same class
/// of bug fixed earlier in saveGameRecordProvider).
final recordPuzzleAttemptProvider = Provider<
    Future<String> Function({
      required String uid,
      required bool isCorrect,
      required String userSolutionSgf,
    })>((ref) {
  return ({required uid, required isCorrect, required userSolutionSgf}) async {
    final problem = ref.read(currentTsumeProblemProvider);
    if (problem == null) {
      throw Exception('No current puzzle selected');
    }

    _logger.i('Recording puzzle attempt: uid=$uid, correct=$isCorrect');

    final firestoreService = ref.read(tsumeGoFirestoreProvider);
    final log = UserTsumeGoLog(
      id: '', // Firestore will auto-generate
      uid: uid,
      problemId: problem.id,
      isCorrect: isCorrect,
      solvedAt: DateTime.now(),
      attemptCount: ref.read(puzzleAttemptCountProvider),
      solvingTime: Duration(seconds: ref.read(puzzleSolvingTimeProvider)),
      userSolutionSgf: userSolutionSgf,
    );

    try {
      final logId = await firestoreService.saveTsumeGoLog(log);
      if (isCorrect) {
        ref.read(isPuzzleSolvedProvider.notifier).state = true;
        await _incrementPuzzlesSolved(ref, uid);
      } else {
        ref.read(puzzleAttemptCountProvider.notifier).state += 1;
      }
      _logger.i('✅ Puzzle attempt recorded: $logId');
      return logId;
    } catch (e) {
      _logger.e('❌ Failed to record puzzle attempt: $e');
      rethrow;
    }
  };
});

/// 詰碁を正解した回数をリーダーボード（puzzlesタイプ）に反映する。
/// best-effortで行い、失敗しても詰碁の記録自体（recordPuzzleAttempt）は
/// 成功として扱う。
Future<void> _incrementPuzzlesSolved(Ref ref, String uid) async {
  try {
    final displayName = ref.read(currentUserProvider)?.displayName ?? 'Anonymous';
    await ref.read(incrementUserStatsProvider)(
      uid: uid,
      displayName: displayName,
      period: LeaderboardPeriod.allTime,
      type: LeaderboardType.puzzles,
      puzzlesSolvedDelta: 1,
    );
  } catch (e) {
    _logger.w('Failed to update puzzles-solved leaderboard (non-fatal): $e');
  }
}

// ================== STREAK TRACKING ==================

/// User's current tsume-go solving streak (in days)
final tsumeGoStreakProvider = FutureProvider.family<int, String>(
  (ref, uid) async {
    _logger.i('Calculating tsume-go streak for user: $uid');

    final firestoreService = ref.watch(tsumeGoFirestoreProvider);
    try {
      final streak = await firestoreService.getTsumeGoStreak(uid);
      _logger.i('✅ Streak calculated: $streak days');
      return streak;
    } catch (e) {
      _logger.e('❌ Failed to calculate streak: $e');
      rethrow;
    }
  },
);

// ================== DIFFICULTY SELECTION ==================

/// Selected difficulty level (1-5)
final selectedDifficultyProvider = StateProvider<int>((ref) {
  return 1; // Default to easiest
});

/// Available puzzle difficulties with labels
final difficultyLevelsProvider = Provider<Map<int, String>>((ref) {
  return {
    1: '初心者向け (Beginner)',
    2: '初級 (Elementary)',
    3: '中級 (Intermediate)',
    4: '上級 (Advanced)',
    5: 'プロ級 (Professional)',
  };
});

/// Switch to different difficulty
final setDifficultyProvider = Provider<void Function(int)>((ref) {
  return (difficulty) {
    _logger.i('Switching to difficulty: $difficulty');
    ref.read(selectedDifficultyProvider.notifier).state = difficulty;
  };
});

// ================== PUZZLE HISTORY ==================

/// Get user's tsume-go solving history
final userTsumeGoLogsProvider = FutureProvider.family<List<UserTsumeGoLog>, String>(
  (ref, uid) async {
    _logger.i('Fetching tsume-go logs for user: $uid');

    final firestoreService = ref.watch(tsumeGoFirestoreProvider);
    try {
      // TBD: Implement paginated fetch in FirestoreService
      // For now, get recent attempts by fetching streak and working backwards
      final streak = await firestoreService.getTsumeGoStreak(uid);
      _logger.i('✅ Streak fetched: $streak days');

      // Return empty list for now - will be populated by detail fetch
      return [];
    } catch (e) {
      _logger.e('❌ Failed to fetch tsume-go logs: $e');
      rethrow;
    }
  },
);

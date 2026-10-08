import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/board_state.dart';
import 'package:komovia_go/models/tsume_go_problem.dart';

import 'go_position.dart';

/// Converts komovia_go's existing tsume-go puzzles (`TsumeGoProblem`) into
/// `komovia_core`'s game-agnostic `Puzzle<GoPosition>`.
///
/// Unlike komovia_shogi's puzzle sources (hand-made 詰将棋 JSON, lishogi
/// imports — see `ShogiPuzzle`), which carry a real move-by-move
/// solution, `TsumeGoProblem.solutionSgf` is **only a final-position
/// snapshot** — the same "app's own SGF dialect" `BoardState.toSgf()`
/// produces (see that class's doc comment), with no move order at all.
/// `checkPuzzleSolutionProvider` (`tsume_go_provider.dart`) confirms this:
/// it checks a solved puzzle by comparing the live board's final stone
/// layout against this snapshot, never by validating a move sequence.
///
/// Reverse-engineering a move-by-move `List<Move>` from just the before/
/// after stone diff would not be sound in general — a real tsume-go
/// solution can involve captures that remove stones never present in
/// either snapshot, so a point-by-point diff cannot recover a legal
/// alternating-move order. Rather than fabricate one, [solution] is left
/// empty and the real final-position data is preserved losslessly in
/// [Puzzle.metadata]'s `'solutionSgf'` key, in the app's own dialect —
/// exactly what `checkPuzzleSolutionProvider` already needs to grade an
/// attempt, just carried through `Puzzle` instead of `TsumeGoProblem`
/// directly.
class GoPuzzle {
  GoPuzzle._();

  static Puzzle<GoPosition> fromTsumeGoProblem(
    TsumeGoProblem problem, {
    required String gameId,
  }) {
    final boardState = BoardState.fromSgf(problem.sgfData);
    final position = GoPosition(boardState: boardState);

    return Puzzle(
      id: problem.id,
      gameId: gameId,
      position: position,
      // See the class-level comment: no sound move-by-move
      // reconstruction is possible from a final-snapshot-only source.
      solution: const [],
      title: '${problem.getDifficultyName()} (${problem.source})',
      metadata: {
        'difficulty': problem.difficulty,
        'solutionSgf': problem.solutionSgf,
        'explanation': problem.explanation,
        'source': problem.source,
        if (problem.expectedMoves != null) 'expectedMoves': problem.expectedMoves,
      },
    );
  }
}

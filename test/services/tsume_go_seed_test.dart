import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/board_state.dart';
import 'package:komovia_go/models/tsume_go_problem.dart';
import 'package:komovia_go/services/go_rules.dart';

/// The (row, col) black plays to solve each puzzle below, kept separate
/// from the seed JSON itself (which only needs the fields the real
/// TsumeGoProblem model/Firestore documents actually have) so this test
/// can independently replay each solution through GoRules and confirm it
/// really produces the stored solutionSgf — the same board-grid
/// comparison checkPuzzleSolutionProvider performs at runtime.
const _solutionMoves = {
  'puzzle_diff1_001': (row: 0, col: 0),
  'puzzle_diff2_001': (row: 5, col: 4),
  'puzzle_diff3_001': (row: 2, col: 1),
  'puzzle_diff4_001': (row: 6, col: 5),
  'puzzle_diff5_001': (row: 3, col: 4),
};

bool _boardsMatch(BoardState a, BoardState b) {
  if (a.boardSize != b.boardSize) return false;
  for (var r = 0; r < a.boardSize; r++) {
    for (var c = 0; c < a.boardSize; c++) {
      if (a.stones[r][c] != b.stones[r][c]) return false;
    }
  }
  return true;
}

void main() {
  test('scripts/seed/tsume_go_problems.json parses as TsumeGoProblem documents '
      'and every puzzle has a verified, GoRules-legal one-move solution', () async {
    final raw = File('scripts/seed/tsume_go_problems.json').readAsStringSync();
    final docs = jsonDecode(raw) as Map<String, dynamic>;
    expect(docs, isNotEmpty);

    final firestore = FakeFirebaseFirestore();
    for (final entry in docs.entries) {
      await firestore.collection('tsumeGoProblems').doc(entry.key).set(
            entry.value as Map<String, dynamic>,
          );
    }

    final difficulties = <int>{};
    for (final id in docs.keys) {
      final snapshot = await firestore.collection('tsumeGoProblems').doc(id).get();
      final problem = TsumeGoProblem.fromFirestore(
        snapshot as DocumentSnapshot<Map<String, dynamic>>,
      );

      expect(problem.difficulty, inInclusiveRange(1, 5));
      expect(problem.sgfData, isNotEmpty);
      expect(problem.solutionSgf, isNotEmpty);
      expect(problem.explanation, isNotEmpty);
      expect(problem.source, isNotEmpty);
      difficulties.add(problem.difficulty);

      final move = _solutionMoves[id];
      expect(move, isNotNull, reason: '$id has no verification move registered');

      final board = BoardState.fromSgf(problem.sgfData);
      final result = GoRules.applyMove(
        stones: board.stones,
        boardSize: board.boardSize,
        row: move!.row,
        col: move.col,
        player: 1, // the player always plays black in tsume-go
      );
      expect(result, isNotNull, reason: '$id: solution move ${move.row},${move.col} is illegal');
      expect(result!.capturedCount, greaterThan(0),
          reason: '$id: solution move captured nothing — is it really the solution?');

      final actualFinal = BoardState(
        boardSize: board.boardSize,
        stones: result.stones,
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: false,
      );
      final expectedFinal = BoardState.fromSgf(problem.solutionSgf);
      expect(
        _boardsMatch(BoardState.fromSgf(actualFinal.toSgf()), expectedFinal),
        isTrue,
        reason: '$id: playing the solution move does not reproduce solutionSgf',
      );
    }

    // getTodaysTsumeProblem() cycles through difficulty 1-5 by day of year
    // and returns null (no puzzle at all that day) if a difficulty has no
    // documents — every difficulty needs at least one problem.
    expect(difficulties, equals({1, 2, 3, 4, 5}));
  });
}

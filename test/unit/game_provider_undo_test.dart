import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../test_utils.dart';

/// Pure-provider tests for undoLastMoveProvider/canUndoProvider -
/// deliberately not widget tests: pumping AIGameScreen with white-to-move
/// board state makes it start a real aiMoveProvider computation (the
/// Fuego engine isn't mocked in this suite), which leaks a pending Timer
/// past test teardown. Exercising the providers directly through a plain
/// ProviderContainer avoids that entirely.
///
/// Uses TestUtils.createTestContainer (overriding currentUserProvider to
/// null) rather than a bare ProviderContainer: startNewGameProvider's
/// best-effort 縁-feature session tracking reads currentUserProvider,
/// which otherwise chains into a real FirebaseAuth platform channel call
/// that isn't mocked for plain (non-widget) tests and throws.
void main() {
  group('undoLastMoveProvider / canUndoProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(currentUser: null);
      addTearDown(container.dispose);
    });

    test('canUndoProvider is false with no moves played', () {
      container.read(startNewGameProvider)(boardSize: 9);
      expect(container.read(canUndoProvider), isFalse);
    });

    test('undo after the player\'s own move (before the AI replies) removes just that move', () {
      container.read(startNewGameProvider)(boardSize: 9);
      container.read(applyMoveProvider)(2, 2);

      expect(container.read(moveHistoryProvider), hasLength(1));
      expect(container.read(gameBoardStateProvider).isBlackTurn, isFalse);
      expect(container.read(canUndoProvider), isTrue);

      container.read(undoLastMoveProvider)();

      expect(container.read(moveHistoryProvider), isEmpty);
      expect(container.read(gameBoardStateProvider).stones[2][2], 0);
      expect(container.read(gameBoardStateProvider).isBlackTurn, isTrue);
      expect(container.read(movesCountProvider), 0);
      expect(container.read(canUndoProvider), isFalse);
    });

    test('undo after the AI has already replied removes both the AI move and the player\'s own', () {
      container.read(startNewGameProvider)(boardSize: 9);
      container.read(applyMoveProvider)(2, 2); // black
      container.read(applyMoveProvider)(3, 3); // white (AI's reply, applied directly here)

      expect(container.read(moveHistoryProvider), hasLength(2));
      expect(container.read(gameBoardStateProvider).isBlackTurn, isTrue);

      container.read(undoLastMoveProvider)();

      expect(container.read(moveHistoryProvider), isEmpty);
      expect(container.read(gameBoardStateProvider).stones[2][2], 0);
      expect(container.read(gameBoardStateProvider).stones[3][3], 0);
      expect(container.read(gameBoardStateProvider).isBlackTurn, isTrue);
    });

    test('undo preserves an earlier move not being undone', () {
      container.read(startNewGameProvider)(boardSize: 9);
      container.read(applyMoveProvider)(0, 0); // black
      container.read(applyMoveProvider)(1, 1); // white
      container.read(applyMoveProvider)(2, 2); // black

      // It's white's turn (right after black's 2nd move) - undo removes
      // just that one move, leaving the first exchange intact.
      container.read(undoLastMoveProvider)();

      final board = container.read(gameBoardStateProvider);
      expect(board.stones[0][0], 1); // black, preserved
      expect(board.stones[1][1], 2); // white, preserved
      expect(board.stones[2][2], 0); // undone
      expect(container.read(moveHistoryProvider), hasLength(2));
      expect(board.isBlackTurn, isTrue);
    });

    test('undo rewinds a capture (stones and capturedBlack/White count)', () {
      container.read(startNewGameProvider)(boardSize: 9);
      // Surround a single white stone at (0,0) (a corner, only 2
      // liberties) with black so the final black move captures it.
      container.read(applyMoveProvider)(1, 1); // black, far away - keeps it black's turn below
      container.read(undoLastMoveProvider)();

      container.read(applyMoveProvider)(5, 0); // black
      container.read(applyMoveProvider)(0, 0); // white, in the corner
      container.read(applyMoveProvider)(0, 1); // black
      container.read(applyMoveProvider)(5, 1); // white, elsewhere
      container.read(applyMoveProvider)(1, 0); // black: captures white at (0,0)

      expect(container.read(gameBoardStateProvider).capturedWhite, 1);
      expect(container.read(gameBoardStateProvider).stones[0][0], 0);

      container.read(undoLastMoveProvider)();

      // The capturing move and white's preceding move are undone; the
      // white stone should be back and capturedWhite rewound to 0.
      expect(container.read(gameBoardStateProvider).capturedWhite, 0);
      expect(container.read(gameBoardStateProvider).stones[0][0], 2);
      expect(container.read(gameBoardStateProvider).stones[1][0], 0);
    });

    test('undo correctly handles a trailing pass', () {
      container.read(startNewGameProvider)(boardSize: 9);
      container.read(applyMoveProvider)(0, 0); // black
      container.read(applyPassProvider)(); // white passes

      expect(container.read(consecutivePassesProvider), 1);
      expect(container.read(gameBoardStateProvider).isBlackTurn, isTrue);

      // It's black's turn (white just passed), so undo removes white's
      // pass AND black's move before it.
      container.read(undoLastMoveProvider)();

      expect(container.read(moveHistoryProvider), isEmpty);
      expect(container.read(consecutivePassesProvider), 0);
      expect(container.read(gameBoardStateProvider).stones[0][0], 0);
    });
  });
}

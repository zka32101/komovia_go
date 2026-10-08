import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/komovia_go_engine.dart';
import 'package:komovia_go/models/tsume_go_problem.dart';

void main() {
  group('GoGame', () {
    test('black moves first (Side.first = black)', () {
      final game = GoGame();
      final pos = game.initialPosition();
      expect(pos.sideToMove, Side.first);
    });

    test('handicap option places black stones and gives white the first move', () {
      final game = GoGame();
      final pos = game.initialPosition(options: {'boardSize': 9, 'handicapStones': 4});
      expect(pos.sideToMove, Side.second);
      var blackStones = 0;
      for (final row in pos.boardState.stones) {
        for (final v in row) {
          if (v == 1) blackStones++;
        }
      }
      expect(blackStones, 4);
    });

    test('two consecutive passes end the game by score', () {
      final game = GoGame();
      var pos = game.initialPosition(options: {'boardSize': 9});
      pos = game.apply(pos, const PassMove());
      expect(game.result(pos).isOngoing, isTrue);
      pos = game.apply(pos, const PassMove());
      final result = game.result(pos);
      expect(result.kind, ResultKind.win);
      // Empty 9x9 board: white wins by komi alone.
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.score);
    });

    test('resignation ends the game for the opponent', () {
      final game = GoGame();
      final pos = game.initialPosition();
      final afterResign = game.apply(pos, ResignMove(pos.sideToMove));
      final result = game.result(afterResign);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.resignation);
    });

    test('capturing a corner white stone increments capturedWhite', () {
      final game = GoGame();
      var pos = game.initialPosition(options: {'boardSize': 9});
      Move drop(int file, int rank) =>
          DropMove(pieceType: GoGame.stonePieceType, to: Square(file, rank));

      pos = game.apply(pos, drop(5, 5)); // B dummy
      pos = game.apply(pos, drop(0, 0)); // W corner (row0,col0)
      pos = game.apply(pos, drop(1, 0)); // B (row0,col1)
      pos = game.apply(pos, drop(6, 6)); // W dummy
      pos = game.apply(pos, drop(0, 1)); // B (row1,col0) -> captures W corner
      expect(pos.boardState.capturedWhite, 1);
      expect(pos.boardState.stones[0][0], 0);
    });

    test('rejects a BoardMove (go has no on-board move)', () {
      final game = GoGame();
      final pos = game.initialPosition();
      expect(
        () => game.apply(pos, const BoardMove(from: Square(0, 0), to: Square(1, 0))),
        throwsArgumentError,
      );
    });
  });

  group('GoEngine', () {
    test('bestMove returns a move for either side without throwing', () async {
      final engine = GoEngine();
      final game = GoGame();
      final pos = game.initialPosition(options: {'boardSize': 9});
      final move = await engine.bestMove(pos, level: 1);
      expect(move, isNotNull);
    });

    test('evaluate is fixed to black perspective (positive komi-only favors white)', () async {
      final engine = GoEngine();
      final game = GoGame();
      final pos = game.initialPosition(options: {'boardSize': 9});
      final score = await engine.evaluate(pos);
      // Empty board: only komi (white) on the board, so black's
      // perspective score should be negative.
      expect(score, lessThan(0));
    });

    test('modelVersion is builtin', () {
      expect(GoEngine().modelVersion, 'builtin');
    });

    test('findForcedWin returns null (no solver yet)', () async {
      final engine = GoEngine();
      final game = GoGame();
      final pos = game.initialPosition();
      expect(await engine.findForcedWin(pos, maxPly: 5), isNull);
    });
  });

  group('GoHandicapRule', () {
    test('places the expected stone count and sets white to move', () {
      final game = GoGame();
      final standard = game.initialPosition(options: {'boardSize': 9});
      final handicapped = GoHandicapRule.four.apply(standard);
      expect(handicapped.sideToMove, Side.second);
      var blackStones = 0;
      for (final row in handicapped.boardState.stones) {
        for (final v in row) {
          if (v == 1) blackStones++;
        }
      }
      expect(blackStones, 4);
    });
  });

  group('GoPuzzle', () {
    test('wraps a TsumeGoProblem into a Puzzle with the final snapshot in metadata', () {
      final problem = TsumeGoProblem(
        id: 'p1',
        difficulty: 2,
        sgfData: '(;GM[1]SZ[9];B[c,c])',
        solutionSgf: '(;GM[1]SZ[9];B[c,c];W[d,d])',
        explanation: 'test',
        source: 'test-source',
        version: 1,
        createdAt: DateTime(2026, 1, 1),
      );
      final puzzle = GoPuzzle.fromTsumeGoProblem(problem, gameId: 'go');
      expect(puzzle.gameId, 'go');
      expect(puzzle.position.boardState.boardSize, 9);
      expect(puzzle.solution, isEmpty);
      expect(puzzle.metadata['solutionSgf'], problem.solutionSgf);
      expect(puzzle.metadata['difficulty'], 2);
    });
  });
}

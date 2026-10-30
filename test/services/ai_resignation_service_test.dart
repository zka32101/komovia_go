import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/ai_resignation_service.dart';

List<List<int>> _emptyBoard(int size) =>
    List.generate(size, (_) => List.filled(size, 0));

void main() {
  group('AiResignationService.isHopelesslyBehind', () {
    const boardSize = 9;
    final total = boardSize * boardSize;

    test('returns false before enough of the board has been played', () {
      // A single stone each - far below minBoardFractionPlayed, even
      // though the "margin" condition alone would already be satisfied
      // by an empty board (one color has literally everything).
      final stones = _emptyBoard(boardSize);
      stones[0][0] = 2; // white's one stone
      // No black stones at all - the margin would read as the whole
      // board, but this must still return false since so little has
      // been played that the estimate is meaningless.
      final result = AiResignationService.isHopelesslyBehind(
        stones: stones,
        boardSize: boardSize,
        aiIsBlack: true,
      );
      expect(result, isFalse);
    });

    test('returns false once enough is played but the game is close', () {
      final stones = _emptyBoard(boardSize);
      // Fill a majority of the board with an even, interleaved split so
      // there's no lopsided territory - close to a dead-even game.
      var toggle = true;
      var filled = 0;
      final minPlayed = (total * AiResignationService.minBoardFractionPlayed)
          .ceil();
      outer:
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if (filled >= minPlayed + 10) break outer;
          stones[r][c] = toggle ? 1 : 2;
          toggle = !toggle;
          filled++;
        }
      }

      final result = AiResignationService.isHopelesslyBehind(
        stones: stones,
        boardSize: boardSize,
        aiIsBlack: true,
      );
      expect(result, isFalse);
    });

    test(
      'returns true once enough is played and the AI (black) is far behind',
      () {
        final stones = _emptyBoard(boardSize);
        // White owns the entire top two-thirds of the board (stones +
        // the territory they surround); black has a small cluster in one
        // corner. This is well past both thresholds.
        for (var r = 0; r < 6; r++) {
          for (var c = 0; c < boardSize; c++) {
            stones[r][c] = 2;
          }
        }
        stones[8][0] = 1;
        stones[8][1] = 1;
        stones[7][0] = 1;

        final result = AiResignationService.isHopelesslyBehind(
          stones: stones,
          boardSize: boardSize,
          aiIsBlack: true,
        );
        expect(result, isTrue);
      },
    );

    test(
      'returns true when the AI plays white and black is dominating',
      () {
        final stones = _emptyBoard(boardSize);
        for (var r = 0; r < 6; r++) {
          for (var c = 0; c < boardSize; c++) {
            stones[r][c] = 1;
          }
        }
        stones[8][0] = 2;
        stones[8][1] = 2;
        stones[7][0] = 2;

        final result = AiResignationService.isHopelesslyBehind(
          stones: stones,
          boardSize: boardSize,
          aiIsBlack: false,
        );
        expect(result, isTrue);
      },
    );

    test('returns false when the AI is actually the one ahead', () {
      final stones = _emptyBoard(boardSize);
      // Black (the AI here) owns the majority instead.
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < boardSize; c++) {
          stones[r][c] = 1;
        }
      }
      stones[8][0] = 2;
      stones[8][1] = 2;
      stones[7][0] = 2;

      final result = AiResignationService.isHopelesslyBehind(
        stones: stones,
        boardSize: boardSize,
        aiIsBlack: true,
      );
      expect(result, isFalse);
    });
  });
}

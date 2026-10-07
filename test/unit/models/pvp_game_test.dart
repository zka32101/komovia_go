import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/pvp_game.dart';

void main() {
  group('PvpGame.canClaimAbandonmentForfeit', () {
    const threshold = Duration(hours: 48);

    PvpGame buildGame({
      required DateTime updatedAt,
      bool isBlackTurn = true,
      String status = 'active',
    }) {
      return PvpGame(
        id: 'game-1',
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
        stones: List.generate(9, (_) => List.filled(9, 0)),
        isBlackTurn: isBlackTurn,
        capturedBlack: 0,
        capturedWhite: 0,
        movesCount: 0,
        consecutivePasses: 0,
        status: status,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        updatedAt: updatedAt,
      );
    }

    test('is false when the game is still fresh', () {
      final game = buildGame(updatedAt: DateTime.now());
      expect(game.canClaimAbandonmentForfeit('white', threshold: threshold), isFalse);
    });

    test('is true for the waiting player once the game has gone stale', () {
      final game = buildGame(
        updatedAt: DateTime.now().subtract(threshold + const Duration(hours: 1)),
        isBlackTurn: true,
      );
      // It's black's turn, so white is waiting and may claim.
      expect(game.canClaimAbandonmentForfeit('white', threshold: threshold), isTrue);
    });

    test('is false for the player whose own turn it currently is', () {
      final game = buildGame(
        updatedAt: DateTime.now().subtract(threshold + const Duration(hours: 1)),
        isBlackTurn: true,
      );
      expect(game.canClaimAbandonmentForfeit('black', threshold: threshold), isFalse);
    });

    test('is false for a non-participant', () {
      final game = buildGame(
        updatedAt: DateTime.now().subtract(threshold + const Duration(hours: 1)),
      );
      expect(game.canClaimAbandonmentForfeit('stranger', threshold: threshold), isFalse);
    });

    test('is false once the game has already finished', () {
      final game = buildGame(
        updatedAt: DateTime.now().subtract(threshold + const Duration(hours: 1)),
        status: 'finished',
      );
      expect(game.canClaimAbandonmentForfeit('white', threshold: threshold), isFalse);
    });

    test('falls back to createdAt when updatedAt was never set', () {
      final game = PvpGame(
        id: 'game-2',
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
        stones: List.generate(9, (_) => List.filled(9, 0)),
        isBlackTurn: true,
        capturedBlack: 0,
        capturedWhite: 0,
        movesCount: 0,
        consecutivePasses: 0,
        status: 'active',
        createdAt: DateTime.now().subtract(threshold + const Duration(hours: 1)),
      );
      expect(game.canClaimAbandonmentForfeit('white', threshold: threshold), isTrue);
    });
  });
}

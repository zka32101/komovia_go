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

  group('PvpGame clock', () {
    PvpGame buildClockGame({
      bool isBlackTurn = true,
      int mainTimeSeconds = 600,
      int incrementSeconds = 10,
      int? blackTimeMs,
      int? whiteTimeMs,
      DateTime? turnStartedAt,
      String status = 'active',
    }) {
      return PvpGame(
        id: 'game-clock',
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
        mainTimeSeconds: mainTimeSeconds,
        incrementSeconds: incrementSeconds,
        blackTimeMs: blackTimeMs,
        whiteTimeMs: whiteTimeMs,
        turnStartedAt: turnStartedAt,
        createdAt: DateTime.now(),
      );
    }

    test('defaults each side\'s bank to mainTimeSeconds when not specified', () {
      final game = buildClockGame(mainTimeSeconds: 300);
      expect(game.blackTimeMs, 300000);
      expect(game.whiteTimeMs, 300000);
    });

    test('non-mover\'s remaining time is just their stored bank', () {
      final game = buildClockGame(
        isBlackTurn: true,
        whiteTimeMs: 45000,
        turnStartedAt: DateTime.now(),
      );
      expect(game.remainingMs(false, DateTime.now()), 45000);
    });

    test('mover\'s remaining time ticks down live from turnStartedAt', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 60000,
        turnStartedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      final remaining = game.remainingMs(true, DateTime.now());
      expect(remaining, lessThanOrEqualTo(50000));
      expect(remaining, greaterThan(45000));
    });

    test('remainingMs never goes below zero', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 1000,
        turnStartedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(game.remainingMs(true, DateTime.now()), 0);
    });

    test(
      'canClaimTimeoutForfeit is true once the opponent, who is to move, hits zero',
      () {
        final game = buildClockGame(
          isBlackTurn: true,
          blackTimeMs: 0,
          turnStartedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        );
        expect(game.canClaimTimeoutForfeit('white', DateTime.now()), isTrue);
      },
    );

    test('canClaimTimeoutForfeit is false for the player whose own turn it is', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 0,
        turnStartedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(game.canClaimTimeoutForfeit('black', DateTime.now()), isFalse);
    });

    test('canClaimTimeoutForfeit is false when the mover still has time left', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 60000,
        turnStartedAt: DateTime.now(),
      );
      expect(game.canClaimTimeoutForfeit('white', DateTime.now()), isFalse);
    });

    test('canClaimTimeoutForfeit is false for a non-participant', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 0,
        turnStartedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(game.canClaimTimeoutForfeit('stranger', DateTime.now()), isFalse);
    });

    test('canClaimTimeoutForfeit is false once the game has already finished', () {
      final game = buildClockGame(
        isBlackTurn: true,
        blackTimeMs: 0,
        turnStartedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        status: 'finished',
      );
      expect(game.canClaimTimeoutForfeit('white', DateTime.now()), isFalse);
    });

    test('toFirestore/fromFirestore round-trips the clock fields', () {
      final turnStartedAt = DateTime.now().subtract(const Duration(seconds: 3));
      final game = buildClockGame(
        mainTimeSeconds: 300,
        incrementSeconds: 5,
        blackTimeMs: 123456,
        whiteTimeMs: 234567,
        turnStartedAt: turnStartedAt,
      );
      final data = game.toFirestore();
      expect(data['mainTimeSeconds'], 300);
      expect(data['incrementSeconds'], 5);
      expect(data['blackTimeMs'], 123456);
      expect(data['whiteTimeMs'], 234567);
      expect(data['turnStartedAt'], isNotNull);
    });
  });
}

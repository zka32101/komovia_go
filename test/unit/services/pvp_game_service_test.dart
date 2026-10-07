import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/pvp_game_service.dart';

void main() {
  group('PvpGameService', () {
    late FakeFirebaseFirestore firestore;
    late PvpGameService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PvpGameService(firestore);
    });

    test('applyMove places a stone, flips the turn, and rejects an occupied point', () async {
      final game = await service.createGame(
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );

      final applied = await service.applyMove(gameId: game.id, uid: 'black', row: 2, col: 2);
      expect(applied, true);

      final afterFirstMove = await service.getGame(game.id);
      expect(afterFirstMove!.stones[2][2], 1);
      expect(afterFirstMove.isBlackTurn, false);
      expect(afterFirstMove.movesCount, 1);

      // Same point is now occupied by black; white attempting it is illegal.
      final rejected = await service.applyMove(gameId: game.id, uid: 'white', row: 2, col: 2);
      expect(rejected, false);
    });

    test('applyMove rejects a move played out of turn', () async {
      final game = await service.createGame(
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );

      // Black moves first; white trying to move next is out of turn.
      final outOfTurn = await service.applyMove(gameId: game.id, uid: 'white', row: 0, col: 0);
      expect(outOfTurn, false);
    });

    test('two consecutive passes end the game with a real area score, not a stones-only guess', () async {
      final game = await service.createGame(
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );

      // Black plays one stone with no white stones on the board at all, so
      // black owns the entire empty board as territory too (81-1 empty
      // points, all bordering black alone) - an overwhelming, unambiguous
      // win for black once both sides pass, distinct from what a
      // stones-only ("1 black stone vs 0 captures") comparison would have
      // shown as barely a 1-point margin.
      await service.applyMove(gameId: game.id, uid: 'black', row: 4, col: 4);
      await service.pass(gameId: game.id, uid: 'white');
      final ended = await service.pass(gameId: game.id, uid: 'black');
      expect(ended, true);

      final finished = await service.getGame(game.id);
      expect(finished!.isFinished, true);
      expect(finished.result, 'score');
      expect(finished.winnerUid, 'black');
      // 1 stone + 80 territory points = 81 for black.
      expect(finished.blackScore, 81.0);
      // 0 stones + 0 territory + 3.75 komi for white.
      expect(finished.whiteScore, 3.75);
    });

    test('resign ends the game immediately in favor of the opponent', () async {
      final game = await service.createGame(
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );

      await service.resign(gameId: game.id, uid: 'black');

      final finished = await service.getGame(game.id);
      expect(finished!.isFinished, true);
      expect(finished.result, 'resignation');
      expect(finished.winnerUid, 'white');
      // Resignation doesn't run area scoring.
      expect(finished.blackScore, null);
      expect(finished.whiteScore, null);
    });

    group('claimAbandonmentForfeit', () {
      Future<void> makeStale(String gameId) async {
        await firestore.collection('pvp_games').doc(gameId).update({
          'updatedAt': Timestamp.fromDate(
            DateTime.now().subtract(PvpGameService.abandonmentThreshold + const Duration(hours: 1)),
          ),
        });
      }

      test('ends the game in favor of the claimant when the opponent has gone stale', () async {
        final game = await service.createGame(
          boardSize: 9,
          blackUid: 'black',
          blackDisplayName: 'Black',
          whiteUid: 'white',
          whiteDisplayName: 'White',
        );
        await makeStale(game.id);

        // It's black's turn (the default after creation), so white is the
        // one waiting and can claim the forfeit.
        await service.claimAbandonmentForfeit(gameId: game.id, claimantUid: 'white');

        final finished = await service.getGame(game.id);
        expect(finished!.isFinished, true);
        expect(finished.result, 'forfeit');
        expect(finished.winnerUid, 'white');
      });

      test('does nothing when the game has not gone stale yet', () async {
        final game = await service.createGame(
          boardSize: 9,
          blackUid: 'black',
          blackDisplayName: 'Black',
          whiteUid: 'white',
          whiteDisplayName: 'White',
        );

        await service.claimAbandonmentForfeit(gameId: game.id, claimantUid: 'white');

        final stillActive = await service.getGame(game.id);
        expect(stillActive!.isActive, true);
      });

      test('does nothing when the claimant is the one whose turn it is', () async {
        final game = await service.createGame(
          boardSize: 9,
          blackUid: 'black',
          blackDisplayName: 'Black',
          whiteUid: 'white',
          whiteDisplayName: 'White',
        );
        await makeStale(game.id);

        // It's black's turn — black is the delinquent party, not white, so
        // black has nothing to claim against themself.
        await service.claimAbandonmentForfeit(gameId: game.id, claimantUid: 'black');

        final stillActive = await service.getGame(game.id);
        expect(stillActive!.isActive, true);
      });

      test('does nothing for a non-participant', () async {
        final game = await service.createGame(
          boardSize: 9,
          blackUid: 'black',
          blackDisplayName: 'Black',
          whiteUid: 'white',
          whiteDisplayName: 'White',
        );
        await makeStale(game.id);

        await service.claimAbandonmentForfeit(gameId: game.id, claimantUid: 'stranger');

        final stillActive = await service.getGame(game.id);
        expect(stillActive!.isActive, true);
      });

      test('does nothing once the game has already finished', () async {
        final game = await service.createGame(
          boardSize: 9,
          blackUid: 'black',
          blackDisplayName: 'Black',
          whiteUid: 'white',
          whiteDisplayName: 'White',
        );
        await service.resign(gameId: game.id, uid: 'black');
        await makeStale(game.id);

        await service.claimAbandonmentForfeit(gameId: game.id, claimantUid: 'white');

        final finished = await service.getGame(game.id);
        // Still the resignation result, not overwritten by a forfeit.
        expect(finished!.result, 'resignation');
      });
    });

    test('attachSpectatorSession persists the spectator session id on the game', () async {
      final game = await service.createGame(
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );
      expect(game.spectatorSessionId, null);

      await service.attachSpectatorSession(game.id, 'session-123');

      final updated = await service.getGame(game.id);
      expect(updated!.spectatorSessionId, 'session-123');
    });

    test('createGameForTournamentMatch only creates one game when called twice for the same match', () async {
      // In production the match doc always exists before a player can tap
      // "対局を開始する" for it — TournamentService's bracket/schedule
      // generation writes every round's match docs up front when the
      // tournament starts.
      await firestore
          .collection('tournaments')
          .doc('t1')
          .collection('matches')
          .doc('m1')
          .set({'gameId': null, 'status': 'pending'});

      final id1 = await service.createGameForTournamentMatch(
        tournamentId: 't1',
        matchId: 'm1',
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );
      final id2 = await service.createGameForTournamentMatch(
        tournamentId: 't1',
        matchId: 'm1',
        boardSize: 9,
        blackUid: 'black',
        blackDisplayName: 'Black',
        whiteUid: 'white',
        whiteDisplayName: 'White',
      );

      expect(id1, id2);
    });
  });
}

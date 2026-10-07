import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/pvp_game.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/viewmodels/friend_provider.dart' as friend_provider;

void main() {
  group('createTournamentGameProvider spectator session wiring', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(overrides: [
        pvpGameServiceProvider.overrideWithValue(PvpGameService(firestore)),
        spectatorServiceProvider.overrideWithValue(SpectatorService(firestore)),
        // friend_activity_provider.dart watches friend_provider.dart's
        // friendServiceProvider specifically, not the one re-exported from
        // viewmodels/index.dart (that barrel resolves the name to
        // social_features_provider.dart's implementation instead - a
        // pre-existing, documented duplicate-name split in this codebase).
        friend_provider.friendServiceProvider
            .overrideWithValue(FriendService(firestore: firestore)),
      ]);
    });

    tearDown(() => container.dispose());

    /// In production the match doc always exists before a player can tap
    /// "対局を開始する" for it (TournamentService writes every round's
    /// match docs up front), which createGameForTournamentMatch's
    /// idempotency relies on - mirrors the same setup already used in
    /// pvp_game_service_test.dart.
    Future<void> seedMatch(String tournamentId, String matchId) {
      return firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('matches')
          .doc(matchId)
          .set({'gameId': null, 'status': 'pending'});
    }

    test('starts a spectator session hosted by the caller when the caller is black', () async {
      await seedMatch('t1', 'm1');
      final gameId = await container.read(createTournamentGameProvider)(
        't1', 'm1', 19, 'black-uid', 'Black', 'white-uid', 'White', 'black-uid',
      );
      await pumpEventQueue();

      final game = await PvpGameService(firestore).getGame(gameId);
      expect(game!.spectatorSessionId, isNotNull);

      final sessions = await SpectatorService(firestore).getGameSpectatorSessions(gameId);
      expect(sessions, hasLength(1));
      expect(sessions.single.hostUid, 'black-uid');
      expect(sessions.single.coHostUid, 'white-uid');
      expect(sessions.single.gameType, 'pvp_game');
    });

    test('starts a spectator session hosted by the caller when the caller is white', () async {
      // Reproduces the bug this fix closes: the tournament bracket fixes
      // black/white by uid ordering, so the player who taps "start" is not
      // always black - the spectator session's hostUid (which Firestore
      // rules require to equal request.auth.uid) must follow the caller,
      // not blindly follow blackUid.
      await seedMatch('t1', 'm1');
      final gameId = await container.read(createTournamentGameProvider)(
        't1', 'm1', 19, 'black-uid', 'Black', 'white-uid', 'White', 'white-uid',
      );
      await pumpEventQueue();

      final sessions = await SpectatorService(firestore).getGameSpectatorSessions(gameId);
      expect(sessions, hasLength(1));
      expect(sessions.single.hostUid, 'white-uid');
      expect(sessions.single.coHostUid, 'black-uid');
    });

    test('does not create a second spectator session when the other participant '
        'also calls it for the same match', () async {
      await seedMatch('t1', 'm1');
      final firstGameId = await container.read(createTournamentGameProvider)(
        't1', 'm1', 19, 'black-uid', 'Black', 'white-uid', 'White', 'black-uid',
      );
      await pumpEventQueue();

      final secondGameId = await container.read(createTournamentGameProvider)(
        't1', 'm1', 19, 'black-uid', 'Black', 'white-uid', 'White', 'white-uid',
      );
      await pumpEventQueue();

      expect(secondGameId, firstGameId);
      final sessions = await SpectatorService(firestore).getGameSpectatorSessions(firstGameId);
      expect(sessions, hasLength(1));
      // The first caller (black) won the transaction, so the session stays
      // hosted by them - the second (white) call must not overwrite it.
      expect(sessions.single.hostUid, 'black-uid');
    });

    // Note: this and the test above only exercise the sequential case
    // (each call fully settles before the next starts). A genuinely
    // concurrent version - firing both calls back-to-back with no await
    // between them - was tried and does catch a real race in the
    // application code (a naive read-then-write guard lets both callers
    // win), but fake_cloud_firestore's runTransaction doesn't serialize
    // concurrent transactions against the same document at all (verified
    // directly: two unawaited attachSpectatorSessionIfAbsent calls on the
    // same freshly-created game both returned true, each clobbering the
    // other's write) - the same limitation the pre-existing
    // "createGameForTournamentMatch only creates one game when called
    // twice" test in pvp_game_service_test.dart already works around by
    // only testing the sequential case. Real Firestore's transactions are
    // genuinely serializable (server-side optimistic-concurrency retry),
    // so PvpGameService.attachSpectatorSessionIfAbsent's correctness there
    // rests on that guarantee plus this suite's sequential coverage of its
    // logic, not on a fake-library concurrency test that tool can't provide.
  });

  group('rematchPvpGameProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(overrides: [
        pvpGameServiceProvider.overrideWithValue(PvpGameService(firestore)),
        spectatorServiceProvider.overrideWithValue(SpectatorService(firestore)),
        friend_provider.friendServiceProvider
            .overrideWithValue(FriendService(firestore: firestore)),
      ]);
    });

    tearDown(() => container.dispose());

    PvpGame finishedGame({required String winnerUid}) => PvpGame(
          id: 'previous-game',
          boardSize: 13,
          blackUid: 'black-uid',
          blackDisplayName: 'Black Player',
          whiteUid: 'white-uid',
          whiteDisplayName: 'White Player',
          stones: List.generate(13, (_) => List.filled(13, 0)),
          isBlackTurn: true,
          capturedBlack: 0,
          capturedWhite: 0,
          movesCount: 42,
          consecutivePasses: 2,
          status: 'finished',
          winnerUid: winnerUid,
          result: 'resignation',
          createdAt: DateTime(2026, 1, 1),
        );

    test('creates a new game with colors swapped from the previous one', () async {
      final previous = finishedGame(winnerUid: 'black-uid');

      final newGame = await container.read(rematchPvpGameProvider)(previous, 'white-uid');

      expect(newGame.boardSize, 13);
      expect(newGame.blackUid, 'white-uid');
      expect(newGame.blackDisplayName, 'White Player');
      expect(newGame.whiteUid, 'black-uid');
      expect(newGame.whiteDisplayName, 'Black Player');
      expect(newGame.isActive, isTrue);
      expect(newGame.id, isNot(equals(previous.id)));
    });

    test('a rematch is a fresh, independent game (not linked to the previous one)',
        () async {
      final previous = finishedGame(winnerUid: 'white-uid');

      final newGame = await container.read(rematchPvpGameProvider)(previous, 'black-uid');

      expect(newGame.movesCount, 0);
      expect(newGame.consecutivePasses, 0);
      expect(newGame.winnerUid, isNull);
      expect(newGame.tournamentId, isNull);
    });

    test('either player can request the rematch', () async {
      final previous = finishedGame(winnerUid: 'black-uid');

      final fromLoser = await container.read(rematchPvpGameProvider)(previous, 'white-uid');
      expect(fromLoser.isActive, isTrue);

      final fromWinner = await container.read(rematchPvpGameProvider)(previous, 'black-uid');
      expect(fromWinner.isActive, isTrue);
      expect(fromWinner.id, isNot(equals(fromLoser.id)));
    });
  });
}

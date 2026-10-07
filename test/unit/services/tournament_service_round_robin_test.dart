import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/tournament.dart';
import 'package:komovia_go/services/tournament_service.dart';

void main() {
  group('TournamentService round_robin', () {
    late FakeFirebaseFirestore firestore;
    late TournamentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TournamentService(firestore);
    });

    Future<String> createRoundRobinTournament(List<String> playerUids) async {
      final tournament = await service.createTournament(
        name: 'Weekend Cup',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: playerUids.length,
        format: 'round_robin',
        createdByUid: playerUids.first,
      );
      final tournamentId = tournament!.id;

      // joinTournament creates the participants/{uid} doc startTournament
      // reads display names from; the creator alone doesn't auto-join.
      for (final uid in playerUids) {
        await service.joinTournament(
          tournamentId: tournamentId,
          uid: uid,
          displayName: 'Player $uid',
        );
      }
      return tournamentId;
    }

    test('generates every pairing exactly once for an even player count', () async {
      final players = ['p1', 'p2', 'p3', 'p4'];
      final tournamentId = await createRoundRobinTournament(players);

      await service.startTournament(tournamentId);

      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      // 4 players -> C(4,2) = 6 matches, no byes needed (even count).
      expect(matches.length, 6);

      final pairsSeen = <Set<String>>{};
      for (final m in matches) {
        expect(m.player1Uid, isNotNull);
        expect(m.player2Uid, isNotNull);
        final pair = {m.player1Uid!, m.player2Uid!};
        expect(pairsSeen.contains(pair), isFalse, reason: 'pair $pair scheduled twice');
        pairsSeen.add(pair);
      }

      // Every unordered pair among the 4 players appears exactly once.
      final expectedPairs = <Set<String>>{};
      for (var i = 0; i < players.length; i++) {
        for (var j = i + 1; j < players.length; j++) {
          expectedPairs.add({players[i], players[j]});
        }
      }
      expect(pairsSeen, expectedPairs);

      final tournament = await service.getTournament(tournamentId);
      expect(tournament!.status, 'active');
    });

    test('an odd player count gives everyone exactly one bye round', () async {
      final players = ['p1', 'p2', 'p3'];
      final tournamentId = await createRoundRobinTournament(players);

      await service.startTournament(tournamentId);

      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      // 3 players -> C(3,2) = 3 matches across 3 rounds (one bye per round).
      expect(matches.length, 3);

      final matchesPerPlayer = <String, int>{};
      for (final m in matches) {
        matchesPerPlayer[m.player1Uid!] = (matchesPerPlayer[m.player1Uid!] ?? 0) + 1;
        matchesPerPlayer[m.player2Uid!] = (matchesPerPlayer[m.player2Uid!] ?? 0) + 1;
      }
      // Each of the 3 players plays the other 2 exactly once.
      for (final uid in players) {
        expect(matchesPerPlayer[uid], 2);
      }
    });

    test('completing every match crowns the player with the most wins', () async {
      final players = ['p1', 'p2', 'p3', 'p4'];
      final tournamentId = await createRoundRobinTournament(players);
      await service.startTournament(tournamentId);

      // p1 beats everyone (3 wins); everyone else beats only each other once.
      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      for (final m in matches) {
        final winner = m.player1Uid == 'p1' || m.player2Uid == 'p1'
            ? 'p1'
            : m.player1Uid!; // arbitrary but deterministic among the rest
        await service.recordMatchResult(
          tournamentId: tournamentId,
          matchId: m.id,
          winnerUid: winner,
        );
      }

      final tournament = await service.getTournament(tournamentId);
      expect(tournament!.status, 'completed');
      expect(tournament.winnerId, 'p1');

      final standings = await service.getStandings(tournamentId);
      expect(standings.first.uid, 'p1');
      expect(standings.first.wins, 3);
      expect(standings.first.losses, 0);
    });

    test('does not complete the tournament until every match is played', () async {
      final players = ['p1', 'p2', 'p3', 'p4'];
      final tournamentId = await createRoundRobinTournament(players);
      await service.startTournament(tournamentId);

      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      // Record all but one result.
      for (final m in matches.take(matches.length - 1)) {
        await service.recordMatchResult(
          tournamentId: tournamentId,
          matchId: m.id,
          winnerUid: m.player1Uid!,
        );
      }

      final tournament = await service.getTournament(tournamentId);
      expect(tournament!.status, 'active');
      expect(tournament.winnerId, isNull);
    });

    test('startTournament rejects an unknown format', () async {
      final tournamentId = await createRoundRobinTournament(['p1', 'p2']);
      // Overwrite the format directly to simulate an invalid format, since
      // createTournament/joinTournament don't validate the format string.
      await firestore.collection('tournaments').doc(tournamentId).update({'format': 'bogus'});

      expect(
        () => service.startTournament(tournamentId),
        throwsA(isA<Exception>()),
      );
    });
  });
}

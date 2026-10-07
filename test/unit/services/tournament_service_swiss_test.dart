import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/tournament.dart';
import 'package:komovia_go/services/tournament_service.dart';

void main() {
  group('TournamentService swiss', () {
    late FakeFirebaseFirestore firestore;
    late TournamentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TournamentService(firestore);
    });

    Future<String> createSwissTournament(List<String> playerUids) async {
      final tournament = await service.createTournament(
        name: 'Swiss Cup',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: playerUids.length,
        format: 'swiss',
        createdByUid: playerUids.first,
      );
      final tournamentId = tournament!.id;
      for (final uid in playerUids) {
        await service.joinTournament(
          tournamentId: tournamentId,
          uid: uid,
          displayName: 'Player $uid',
        );
      }
      return tournamentId;
    }

    test('startTournament computes totalRounds and generates round 1 pairing everyone once',
        () async {
      final players = ['p1', 'p2', 'p3', 'p4'];
      final tournamentId = await createSwissTournament(players);

      await service.startTournament(tournamentId);

      final tournament = await service.getTournament(tournamentId);
      expect(tournament!.isActive, true);
      expect(tournament.totalRounds, greaterThanOrEqualTo(3));

      final round1 = await service.getTournamentMatches(tournamentId: tournamentId, round: 1);
      // 4 players, even count -> 2 matches, no bye.
      expect(round1.length, 2);
      final playersInRound1 = round1.expand((m) => [m.player1Uid, m.player2Uid]).toSet();
      expect(playersInRound1, players.toSet());
    });

    test('odd player count gives exactly one bye per round, auto-completed', () async {
      final players = ['p1', 'p2', 'p3'];
      final tournamentId = await createSwissTournament(players);

      await service.startTournament(tournamentId);

      final round1 = await service.getTournamentMatches(tournamentId: tournamentId, round: 1);
      final byes = round1.where((m) => m.isBye).toList();
      expect(byes.length, 1);
      expect(byes.first.status, 'completed');
      expect(byes.first.winnerUid, byes.first.player1Uid);
      // 1 bye + 1 real match = 3 players' worth of match slots.
      expect(round1.length, 2);
    });

    test('advances to the next round only once all of the current round is complete, without a rematch',
        () async {
      final players = ['p1', 'p2', 'p3', 'p4'];
      final tournamentId = await createSwissTournament(players);
      await service.startTournament(tournamentId);

      final round1 = await service.getTournamentMatches(tournamentId: tournamentId, round: 1);
      expect(round1.length, 2);

      // Complete only the first match - round 2 must not appear yet.
      await service.recordMatchResult(
        tournamentId: tournamentId,
        matchId: round1[0].id,
        winnerUid: round1[0].player1Uid!,
      );
      var round2 = await service.getTournamentMatches(tournamentId: tournamentId, round: 2);
      expect(round2, isEmpty);

      // Completing the second (last) match of round 1 should generate round 2.
      await service.recordMatchResult(
        tournamentId: tournamentId,
        matchId: round1[1].id,
        winnerUid: round1[1].player1Uid!,
      );
      round2 = await service.getTournamentMatches(tournamentId: tournamentId, round: 2);
      expect(round2.length, 2);

      // No pair in round 2 should repeat a round 1 pairing.
      final round1Keys = round1
          .map((m) => ([m.player1Uid, m.player2Uid]..sort()).join('|'))
          .toSet();
      for (final m in round2) {
        final key = ([m.player1Uid, m.player2Uid]..sort()).join('|');
        expect(round1Keys.contains(key), false, reason: 'round 2 repeated a round 1 pairing: $key');
      }
    });

    test('completes the tournament and crowns a champion after the final round', () async {
      final players = ['p1', 'p2'];
      final tournamentId = await createSwissTournament(players);
      await service.startTournament(tournamentId);

      final tournament = await service.getTournament(tournamentId);
      final totalRounds = tournament!.totalRounds;

      // Play every round, p1 always wins.
      for (var round = 1; round <= totalRounds; round++) {
        final matches = await service.getTournamentMatches(tournamentId: tournamentId, round: round);
        for (final m in matches) {
          if (m.isCompleted) continue; // bye, already completed
          await service.recordMatchResult(
            tournamentId: tournamentId,
            matchId: m.id,
            winnerUid: m.player1Uid == 'p1' || m.player2Uid == 'p1' ? 'p1' : m.player1Uid!,
          );
        }
      }

      final finished = await service.getTournament(tournamentId);
      expect(finished!.isCompleted, true);
      expect(finished.winnerId, 'p1');
    });

    test('startTournament rejects with fewer than 2 participants', () async {
      final tournament = await service.createTournament(
        name: 'Too small',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: 8,
        format: 'swiss',
        createdByUid: 'p1',
      );
      await service.joinTournament(tournamentId: tournament!.id, uid: 'p1', displayName: 'P1');

      expect(() => service.startTournament(tournament.id), throwsException);
    });
  });

  group('TournamentStandingEntry played getter', () {
    test('sums wins and losses', () {
      final entry = TournamentStandingEntry(uid: 'p1', displayName: 'P1', wins: 2, losses: 1);
      expect(entry.played, 3);
    });
  });
}

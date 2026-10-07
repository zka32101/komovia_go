import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/notification_service.dart';
import 'package:komovia_go/services/tournament_service.dart';

void main() {
  group('TournamentService tournament_match notifications', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService notificationService;
    late TournamentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      notificationService = NotificationService(firestore: firestore);
      service = TournamentService(firestore, notificationService);
    });

    Future<String> createAndJoin({
      required List<String> playerUids,
      String format = 'single_elimination',
    }) async {
      final tournament = await service.createTournament(
        name: 'Weekend Cup',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: playerUids.length,
        format: format,
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

    test('single_elimination: both players of a real pairing get notified when the '
        'tournament starts', () async {
      final tournamentId = await createAndJoin(playerUids: ['p1', 'p2', 'p3', 'p4']);

      await service.startTournament(tournamentId);

      final p1Notifications = await notificationService.getUserNotifications('p1');
      final p2Notifications = await notificationService.getUserNotifications('p2');
      expect(p1Notifications.single.type, 'tournament_match');
      expect(p2Notifications.single.type, 'tournament_match');
    });

    test('single_elimination: the bye player (no real opponent) gets no notification',
        () async {
      final tournamentId = await createAndJoin(playerUids: ['p1', 'p2', 'p3']);

      await service.startTournament(tournamentId);

      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      final byeMatch = matches.firstWhere((m) => m.player2Uid == null);
      final byeUid = byeMatch.player1Uid!;

      expect(await notificationService.getUserNotifications(byeUid), isEmpty);
    });

    test('single_elimination: advancing to round 2 notifies the new pairing', () async {
      final tournamentId = await createAndJoin(playerUids: ['p1', 'p2', 'p3', 'p4']);
      await service.startTournament(tournamentId);

      final round1 = await service.getTournamentMatches(tournamentId: tournamentId, round: 1);
      for (final match in round1) {
        await service.recordMatchResult(
          tournamentId: tournamentId,
          matchId: match.id,
          winnerUid: match.player1Uid!,
        );
      }

      final round2Winners = round1.map((m) => m.player1Uid!).toSet();
      for (final uid in round2Winners) {
        final notifications = await notificationService.getUserNotifications(uid);
        // One for round 1's pairing, one for round 2's.
        expect(notifications.where((n) => n.type == 'tournament_match').length, 2);
      }
    });

    test('round_robin: every real pairing is notified once the full schedule is '
        'generated at tournament start', () async {
      final tournamentId = await createAndJoin(
        playerUids: ['p1', 'p2', 'p3', 'p4'],
        format: 'round_robin',
      );

      await service.startTournament(tournamentId);

      // 4 players round-robin -> each plays 3 matches -> 3 notifications each.
      for (final uid in ['p1', 'p2', 'p3', 'p4']) {
        final notifications = await notificationService.getUserNotifications(uid);
        expect(notifications.where((n) => n.type == 'tournament_match').length, 3);
      }
    });

    test('swiss: round 1 pairings are notified at tournament start', () async {
      final tournamentId = await createAndJoin(
        playerUids: ['p1', 'p2', 'p3', 'p4'],
        format: 'swiss',
      );

      await service.startTournament(tournamentId);

      final matches = await service.getTournamentMatches(tournamentId: tournamentId);
      for (final match in matches) {
        final notifications = await notificationService.getUserNotifications(match.player1Uid!);
        expect(notifications.where((n) => n.type == 'tournament_match').length, 1);
      }
    });

    test('with no NotificationService injected, starting a tournament still '
        'succeeds (notification sending is best-effort)', () async {
      final plainService = TournamentService(firestore);
      final tournamentId = await (() async {
        final tournament = await plainService.createTournament(
          name: 'Weekend Cup',
          description: 'test',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 1, 8),
          maxParticipants: 2,
          format: 'single_elimination',
          createdByUid: 'p1',
        );
        for (final uid in ['p1', 'p2']) {
          await plainService.joinTournament(
            tournamentId: tournament!.id,
            uid: uid,
            displayName: 'Player $uid',
          );
        }
        return tournament!.id;
      })();

      await plainService.startTournament(tournamentId);

      final matches = await plainService.getTournamentMatches(tournamentId: tournamentId);
      expect(matches, hasLength(1));
    });
  });
}

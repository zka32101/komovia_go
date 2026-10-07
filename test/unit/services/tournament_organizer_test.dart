import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/tournament_service.dart';

void main() {
  group('TournamentService organizer controls', () {
    late FakeFirebaseFirestore firestore;
    late TournamentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TournamentService(firestore);
    });

    Future<String> createUpcomingTournament({String createdBy = 'organizer'}) async {
      final tournament = await service.createTournament(
        name: 'Weekend Cup',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: 8,
        format: 'single_elimination',
        createdByUid: createdBy,
      );
      return tournament!.id;
    }

    test('cancelTournament sets status to cancelled for the organizer', () async {
      final id = await createUpcomingTournament();
      await service.cancelTournament(tournamentId: id, uid: 'organizer');

      final tournament = await service.getTournament(id);
      expect(tournament!.isCancelled, true);
    });

    test('cancelTournament rejects a non-organizer', () async {
      final id = await createUpcomingTournament();
      expect(
        () => service.cancelTournament(tournamentId: id, uid: 'someone-else'),
        throwsException,
      );
    });

    test('cancelTournament rejects an already-completed tournament', () async {
      final id = await createUpcomingTournament();
      await firestore.collection('tournaments').doc(id).update({'status': 'completed'});
      expect(
        () => service.cancelTournament(tournamentId: id, uid: 'organizer'),
        throwsException,
      );
    });

    test('deleteTournament removes an upcoming tournament for the organizer', () async {
      final id = await createUpcomingTournament();
      await service.deleteTournament(tournamentId: id, uid: 'organizer');

      final tournament = await service.getTournament(id);
      expect(tournament, null);
    });

    test('deleteTournament rejects a non-organizer', () async {
      final id = await createUpcomingTournament();
      expect(
        () => service.deleteTournament(tournamentId: id, uid: 'someone-else'),
        throwsException,
      );
    });

    test('deleteTournament rejects a tournament that already started', () async {
      final id = await createUpcomingTournament();
      await service.joinTournament(tournamentId: id, uid: 'p1', displayName: 'P1');
      await service.joinTournament(tournamentId: id, uid: 'p2', displayName: 'P2');
      await service.startTournament(id);

      expect(
        () => service.deleteTournament(tournamentId: id, uid: 'organizer'),
        throwsException,
      );
      // Still there, untouched.
      expect(await service.getTournament(id), isNotNull);
    });

    test('updateTournament applies only the given fields for the organizer', () async {
      final id = await createUpcomingTournament();
      await service.updateTournament(
        tournamentId: id,
        uid: 'organizer',
        name: 'Renamed Cup',
        maxParticipants: 16,
      );

      final tournament = await service.getTournament(id);
      expect(tournament!.name, 'Renamed Cup');
      expect(tournament.maxParticipants, 16);
      expect(tournament.description, 'test'); // untouched
    });

    test('updateTournament rejects a non-organizer', () async {
      final id = await createUpcomingTournament();
      expect(
        () => service.updateTournament(tournamentId: id, uid: 'someone-else', name: 'Hacked'),
        throwsException,
      );
    });

    test('updateTournament rejects a tournament that already started', () async {
      final id = await createUpcomingTournament();
      await service.joinTournament(tournamentId: id, uid: 'p1', displayName: 'P1');
      await service.joinTournament(tournamentId: id, uid: 'p2', displayName: 'P2');
      await service.startTournament(id);

      expect(
        () => service.updateTournament(tournamentId: id, uid: 'organizer', name: 'Too late'),
        throwsException,
      );
    });

    test('updateTournament rejects shrinking maxParticipants below the current headcount', () async {
      final id = await createUpcomingTournament();
      await service.joinTournament(tournamentId: id, uid: 'p1', displayName: 'P1');
      await service.joinTournament(tournamentId: id, uid: 'p2', displayName: 'P2');
      await service.joinTournament(tournamentId: id, uid: 'p3', displayName: 'P3');

      expect(
        () => service.updateTournament(tournamentId: id, uid: 'organizer', maxParticipants: 2),
        throwsException,
      );
    });
  });
}

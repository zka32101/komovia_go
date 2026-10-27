import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/tournament_service.dart';

/// joinTournament()のレース条件に対する回帰テスト。
///
/// 以前はisFullチェック(読み取り)と参加者ドキュメント作成/
/// participantUids更新(書き込み)がトランザクション無しの別々の
/// Firestore呼び出しだったため、2人が同じタイミングで参加を実行すると
/// 両者が同じ(更新前の)participantUidsを見てisFullチェックを通過し、
/// maxParticipantsを超えて参加できてしまっていた。
void main() {
  group('TournamentService.joinTournament', () {
    late FakeFirebaseFirestore firestore;
    late TournamentService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = TournamentService(firestore);
    });

    Future<String> createTournament({int maxParticipants = 2}) async {
      final tournament = await service.createTournament(
        name: 'Test Cup',
        description: 'test',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 8),
        maxParticipants: maxParticipants,
        format: 'single_elimination',
        createdByUid: 'organizer',
      );
      return tournament!.id;
    }

    test('参加者が追加され、participantUidsとparticipantsサブコレクション両方に反映される',
        () async {
      final id = await createTournament(maxParticipants: 8);
      final ok = await service.joinTournament(
        tournamentId: id,
        uid: 'player1',
        displayName: 'Player One',
      );

      expect(ok, true);
      final tournament = await service.getTournament(id);
      expect(tournament!.participantUids, contains('player1'));

      final participantDoc = await firestore
          .collection('tournaments')
          .doc(id)
          .collection('participants')
          .doc('player1')
          .get();
      expect(participantDoc.exists, true);
      expect(participantDoc.data()!['seed'], 1);
    });

    test('満員のトーナメントへの参加はisFullで拒否される', () async {
      final id = await createTournament(maxParticipants: 1);
      await service.joinTournament(
        tournamentId: id,
        uid: 'player1',
        displayName: 'Player One',
      );

      expect(
        () => service.joinTournament(
          tournamentId: id,
          uid: 'player2',
          displayName: 'Player Two',
        ),
        throwsException,
      );

      final tournament = await service.getTournament(id);
      expect(tournament!.participantUids.length, 1);
    });

    test('同じユーザーが二重に参加しようとしてもno-opで安全(人数は増えない)',
        () async {
      final id = await createTournament(maxParticipants: 8);
      await service.joinTournament(
        tournamentId: id,
        uid: 'player1',
        displayName: 'Player One',
      );
      // 二重タップを想定した再呼び出し。例外を投げず、人数も増えない。
      await service.joinTournament(
        tournamentId: id,
        uid: 'player1',
        displayName: 'Player One',
      );

      final tournament = await service.getTournament(id);
      expect(tournament!.participantUids.length, 1);
    });

    test('maxParticipants人数分はちょうど参加でき、それを超えると拒否される', () async {
      final id = await createTournament(maxParticipants: 3);
      await service.joinTournament(tournamentId: id, uid: 'p1', displayName: 'P1');
      await service.joinTournament(tournamentId: id, uid: 'p2', displayName: 'P2');
      await service.joinTournament(tournamentId: id, uid: 'p3', displayName: 'P3');

      final tournament = await service.getTournament(id);
      expect(tournament!.participantUids.length, 3);
      expect(tournament.isFull, true);

      expect(
        () => service.joinTournament(tournamentId: id, uid: 'p4', displayName: 'P4'),
        throwsException,
      );

      final afterRejected = await service.getTournament(id);
      expect(afterRejected!.participantUids.length, 3);
    });
  });
}

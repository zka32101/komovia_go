import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/en_score_service.dart';

/// EnScoreServiceの回帰テスト。
///
/// 以前は共同観戦セッション数の算出(_countSharedSpectateSessions)が
/// spectatorUids配列のarrayContainsのみで検索していたため、呼び出し元の
/// uidがそのセッションの「観戦者」ではなく「ホスト」だった場合に、その
/// セッションが一件も見つからなかった(spectator_sessionsのhostUidは
/// spectatorUids配列には含まれないため)。結果として、同じペアの縁スコア
/// を計算しても、どちらのuidを先に渡すかによって共同観戦数が非対称に
/// なっていた。
void main() {
  group('EnScoreService._countSharedSpectateSessions (via calculateEnScore)',
      () {
    late FakeFirebaseFirestore firestore;
    late EnScoreService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = EnScoreService(firestore);
    });

    Future<void> seedSession({
      required String hostUid,
      required List<String> spectatorUids,
    }) async {
      await firestore.collection('spectator_sessions').add({
        'hostUid': hostUid,
        'hostDisplayName': 'host',
        'spectatorUids': spectatorUids,
        'spectatorCount': spectatorUids.length,
        'gameId': 'g1',
        'gameType': 'ai',
        'isLive': true,
        'moveIndex': 0,
        'boardSize': 9,
        'stones': [],
        'createdAt': Timestamp.now(),
      });
    }

    test(
        'counts a shared session the same whether the host or the '
        'spectator side requests the score (regression: used to be '
        'asymmetric, returning 0 from the host side)', () async {
      // userAがホスト、userBが観戦者の共同観戦セッションが1件ある。
      await seedSession(hostUid: 'userA', spectatorUids: ['userB']);

      final fromHostSide = await service.calculateEnScore(
        uid: 'userA',
        friendUid: 'userB',
        friendDisplayName: 'B',
        friendshipStartedAt: DateTime.now(),
      );
      final fromSpectatorSide = await service.calculateEnScore(
        uid: 'userB',
        friendUid: 'userA',
        friendDisplayName: 'A',
        friendshipStartedAt: DateTime.now(),
      );

      expect(fromHostSide.sharedSpectateSessions, 1);
      expect(fromSpectatorSide.sharedSpectateSessions, 1);
    });

    test('does not double-count a session where uid is both findable as '
        'host and would also match a separate spectator-side query',
        () async {
      await seedSession(hostUid: 'userA', spectatorUids: ['userB']);

      final result = await service.calculateEnScore(
        uid: 'userA',
        friendUid: 'userB',
        friendDisplayName: 'B',
        friendshipStartedAt: DateTime.now(),
      );

      expect(result.sharedSpectateSessions, 1);
    });

    test('counts sessions where uid is a spectator and friendUid is the '
        'host', () async {
      await seedSession(hostUid: 'userB', spectatorUids: ['userA']);

      final result = await service.calculateEnScore(
        uid: 'userA',
        friendUid: 'userB',
        friendDisplayName: 'B',
        friendshipStartedAt: DateTime.now(),
      );

      expect(result.sharedSpectateSessions, 1);
    });

    test('ignores sessions that do not involve both users', () async {
      await seedSession(hostUid: 'someoneElse', spectatorUids: ['userB']);

      final result = await service.calculateEnScore(
        uid: 'userA',
        friendUid: 'userB',
        friendDisplayName: 'B',
        friendshipStartedAt: DateTime.now(),
      );

      expect(result.sharedSpectateSessions, 0);
    });
  });
}

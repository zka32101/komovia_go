import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/matching_service.dart';

Future<void> _enqueue(
  FakeFirebaseFirestore db, {
  required String uid,
  required DateTime queuedAt,
  int rating = 1200,
  int boardSize = 9,
}) {
  return db.collection('matchmaking_queue').doc(uid).set({
    'uid': uid,
    'displayName': uid,
    'rating': rating,
    'boardSize': boardSize,
    'queuedAt': Timestamp.fromDate(queuedAt),
    'status': 'waiting',
  });
}

void main() {
  late FakeFirebaseFirestore db;
  late MatchingService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = MatchingService(db);
  });

  Future<dynamic> findFor(String uid) => service.findMatch(
        uid: uid,
        displayName: uid,
        rating: 1200,
        boardSize: 9,
      );

  test('待機して間もない相手とはマッチする', () async {
    await _enqueue(db, uid: 'waiting', queuedAt: DateTime.now());
    await _enqueue(db, uid: 'me', queuedAt: DateTime.now());

    final match = await findFor('me');

    expect(match, isNotNull);
    expect(match.player2Uid, 'waiting');
  });

  test('有効期限を過ぎた待機者とはマッチしない', () async {
    final stale = DateTime.now().subtract(
      MatchingService.maxQueueAge + const Duration(minutes: 1),
    );
    await _enqueue(db, uid: 'gone', queuedAt: stale);
    await _enqueue(db, uid: 'me', queuedAt: DateTime.now());

    expect(await findFor('me'), isNull);

    // 期限切れの人は「待機中」のまま、予約もされない。
    final gone = await db.collection('matchmaking_queue').doc('gone').get();
    expect(gone.data()!['status'], 'waiting');
  });

  test('期限切れがいても、期限内の別の待機者を選ぶ', () async {
    final stale = DateTime.now().subtract(
      MatchingService.maxQueueAge + const Duration(minutes: 1),
    );
    // レートはどちらも近いが、期限切れのほうが差が小さい。
    await _enqueue(db, uid: 'gone', queuedAt: stale, rating: 1200);
    await _enqueue(db, uid: 'active', queuedAt: DateTime.now(), rating: 1250);
    await _enqueue(db, uid: 'me', queuedAt: DateTime.now());

    final match = await findFor('me');

    expect(match, isNotNull);
    expect(match.player2Uid, 'active');
  });
}

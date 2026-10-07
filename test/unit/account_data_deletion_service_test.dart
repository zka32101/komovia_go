import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/account_data_deletion_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AccountDataDeletionService service;

  Future<int> count(String path) async => (await db.collection(path).get()).docs.length;

  setUp(() async {
    db = FakeFirebaseFirestore();
    service = AccountDataDeletionService(firestore: db);

    // User A (the one being deleted) and user B (must be untouched).
    for (final uid in ['A', 'B']) {
      await db.collection('users').doc(uid).set({'displayName': uid});
      await db.collection('users/$uid/stats').doc('main').set({'wins': 1});
      await db.collection('users/$uid/gameRecords').doc('g1').set({'x': 1});
      await db.collection('gameRecords').add({'uid': uid, 'sgf': '(;)'});
      await db.collection('userTsumeGoLogs').add({'uid': uid});
      await db.collection('observationLogs').add({'uid': uid});
      await db.collection('notifications/$uid/messages').add({'t': 1});
      await db.collection('notifications/$uid/fcmTokens').doc('tok').set({'t': 1});
      await db.collection('leaderboard_global').doc(uid).set({'rating': 1500});
    }
    // A and B are friends; each has a mirror entry in the other's list.
    await db.collection('users/A/friends').doc('B').set({'uid': 'B'});
    await db.collection('users/B/friends').doc('A').set({'uid': 'A'});
  });

  test('removes all of the user\'s own data and reports no failures', () async {
    final failures = await service.deleteAllUserData('A');

    expect(failures, isEmpty);
    expect((await db.collection('users').doc('A').get()).exists, isFalse);
    expect(await count('users/A/stats'), 0);
    expect(await count('users/A/gameRecords'), 0);
    expect(await count('users/A/friends'), 0);
    expect(
        (await db.collection('gameRecords').where('uid', isEqualTo: 'A').get()).docs,
        isEmpty);
    expect(
        (await db.collection('userTsumeGoLogs').where('uid', isEqualTo: 'A').get()).docs,
        isEmpty);
    expect(
        (await db.collection('observationLogs').where('uid', isEqualTo: 'A').get()).docs,
        isEmpty);
    expect(await count('notifications/A/messages'), 0);
    expect(await count('notifications/A/fcmTokens'), 0);
    expect((await db.collection('leaderboard_global').doc('A').get()).exists, isFalse);
  });

  test('removes the mirror entry from friends\' lists', () async {
    await service.deleteAllUserData('A');
    expect((await db.collection('users/B/friends').doc('A').get()).exists, isFalse);
  });

  test('leaves other users\' data untouched', () async {
    await service.deleteAllUserData('A');

    expect((await db.collection('users').doc('B').get()).exists, isTrue);
    expect(await count('users/B/stats'), 1);
    expect(await count('users/B/gameRecords'), 1);
    expect(
        (await db.collection('gameRecords').where('uid', isEqualTo: 'B').get()).docs.length,
        1);
    expect(await count('notifications/B/messages'), 1);
    expect((await db.collection('leaderboard_global').doc('B').get()).exists, isTrue);
  });

  test('is idempotent: running twice is safe', () async {
    await service.deleteAllUserData('A');
    final failures = await service.deleteAllUserData('A');
    expect(failures, isEmpty);
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/direct_message_service.dart';

void main() {
  group('DirectMessageService', () {
    late FakeFirebaseFirestore firestore;
    late DirectMessageService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = DirectMessageService(firestore);
    });

    test('threadIdFor is deterministic regardless of argument order', () {
      final a = DirectMessageService.threadIdFor('uid1', 'uid2');
      final b = DirectMessageService.threadIdFor('uid2', 'uid1');
      expect(a, equals(b));
      expect(a, equals('uid1_uid2'));
    });

    test('sendMessage creates the thread and the message on first send', () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hello!',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isTrue);
      expect(threadDoc.data()!['lastMessage'], equals('Hello!'));
      expect(threadDoc.data()!['lastSenderUid'], equals('uid1'));
      expect(threadDoc.data()!['unreadCount'], equals({'uid2': 1}));

      final messages = await firestore
          .collection('message_threads')
          .doc(threadId)
          .collection('messages')
          .get();
      expect(messages.docs, hasLength(1));
      expect(messages.docs.first.data()['content'], equals('Hello!'));
      expect(messages.docs.first.data()['fromUid'], equals('uid1'));
    });

    test('sendMessage trims whitespace and ignores an empty/whitespace-only message', () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: '   ',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isFalse);
    });

    test('a second message from the other side increments that side\'s unread count '
        'without resetting the sender\'s own', () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hi Bob',
      );
      await service.sendMessage(
        fromUid: 'uid2',
        fromDisplayName: 'Bob',
        toUid: 'uid1',
        toDisplayName: 'Alice',
        content: 'Hi Alice',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      final unread = Map<String, dynamic>.from(threadDoc.data()!['unreadCount'] as Map);
      expect(unread['uid1'], equals(1));
      expect(unread['uid2'], equals(1));
      expect(threadDoc.data()!['lastMessage'], equals('Hi Alice'));
      expect(threadDoc.data()!['lastSenderUid'], equals('uid2'));

      final messages = await firestore
          .collection('message_threads')
          .doc(threadId)
          .collection('messages')
          .orderBy('sentAt')
          .get();
      expect(messages.docs, hasLength(2));
    });

    test('markThreadRead resets only the given user\'s unread count', () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hi Bob',
      );
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Still there?',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      await service.markThreadRead(threadId: threadId, uid: 'uid2');

      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      final unread = Map<String, dynamic>.from(threadDoc.data()!['unreadCount'] as Map);
      expect(unread['uid2'], equals(0));
    });

    test('markThreadRead on a thread that does not exist yet is a no-op (does not '
        'create a phantom empty conversation)', () async {
      final threadId = DirectMessageService.threadIdFor('ghost1', 'ghost2');
      await service.markThreadRead(threadId: threadId, uid: 'ghost1');

      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isFalse);
    });

    test('watchThreadsForUser only returns threads the user participates in, newest first',
        () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'First thread',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid3',
        toDisplayName: 'Carol',
        content: 'Second thread',
      );
      // uid4 has no conversation with uid1 at all.
      await service.sendMessage(
        fromUid: 'uid4',
        fromDisplayName: 'Dave',
        toUid: 'uid3',
        toDisplayName: 'Carol',
        content: 'Unrelated thread',
      );

      final threads = await service.watchThreadsForUser('uid1').first;
      expect(threads, hasLength(2));
      expect(threads.first.lastMessage, equals('Second thread'));
      expect(threads.map((t) => t.otherUidFor('uid1')), containsAll(['uid2', 'uid3']));
    });

    test('sendMessage refuses when the sender has blocked the recipient', () async {
      await firestore
          .collection('users')
          .doc('uid1')
          .collection('friends')
          .doc('uid2')
          .set({'status': 'blocked'});

      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hello!',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isFalse);
    });

    test('sendMessage refuses when the recipient had blocked the sender '
        '(the block mirrors onto the sender\'s own readable entry)', () async {
      // FriendService.blockFriend mirrors the block onto both sides' own
      // entries, so the sender can detect a block the OTHER party placed
      // just by reading their own (readable) relationship doc.
      await firestore
          .collection('users')
          .doc('uid1')
          .collection('friends')
          .doc('uid2')
          .set({'status': 'blocked', 'blockedBy': 'uid2'});

      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hello!',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isFalse);
    });

    test('watchMessages streams messages in chronological order', () async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'one',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.sendMessage(
        fromUid: 'uid2',
        fromDisplayName: 'Bob',
        toUid: 'uid1',
        toDisplayName: 'Alice',
        content: 'two',
      );

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final messages = await service.watchMessages(threadId).first;
      expect(messages.map((m) => m.content).toList(), equals(['one', 'two']));
    });
  });
}

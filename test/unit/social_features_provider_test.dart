import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

void main() {
  group('addFriendProvider friend_request notification', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(overrides: [
        friendServiceProvider.overrideWithValue(FriendService(firestore: firestore)),
        notificationServiceProvider.overrideWithValue(NotificationService(firestore: firestore)),
      ]);
      await firestore.collection('users').doc('sender').set({'displayName': 'Alice'});
      await firestore.collection('users').doc('recipient').set({'displayName': 'Bob'});
    });

    tearDown(() => container.dispose());

    test('sends a friend_request notification to the recipient on success', () async {
      final success = await container.read(
        addFriendProvider(('sender', 'recipient', 'Alice', null)).future,
      );
      expect(success, true);

      final notificationService = container.read(notificationServiceProvider);
      final notifications = await notificationService.getUserNotifications('recipient');
      expect(notifications, hasLength(1));
      expect(notifications.single.type, 'friend_request');
      expect(notifications.single.title, contains('Alice'));
    });

    test('sends no notification when addFriend refuses (already accepted)', () async {
      final friendService = container.read(friendServiceProvider);
      await friendService.addFriend(currentUid: 'sender', friendUid: 'recipient');
      await friendService.acceptFriendRequest(currentUid: 'sender', friendUid: 'recipient');

      final success = await container.read(
        addFriendProvider(('sender', 'recipient', 'Alice', null)).future,
      );
      expect(success, false);

      final notificationService = container.read(notificationServiceProvider);
      expect(await notificationService.getUserNotifications('recipient'), isEmpty);
    });
  });
}

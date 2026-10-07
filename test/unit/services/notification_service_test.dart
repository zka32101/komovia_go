import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/notification.dart';
import 'package:komovia_go/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = NotificationService(firestore: firestore);
    });

    test('sendNotification then getUserNotifications returns it', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Hello',
        body: 'World',
        type: 'game_invitation',
      );

      final notifications = await service.getUserNotifications('uid1');
      expect(notifications, hasLength(1));
      expect(notifications.single.title, 'Hello');
      expect(notifications.single.isRead, isFalse);
    });

    test('markAsRead flips isRead and sets readAt', () async {
      final id = await service.sendNotification(
        uid: 'uid1',
        title: 'Hello',
        body: 'World',
        type: 'game_invitation',
      );

      await service.markAsRead('uid1', id!);

      final notifications = await service.getUserNotifications('uid1');
      expect(notifications.single.isRead, isTrue);
      expect(notifications.single.readAt, isNotNull);
    });

    test('getNotificationPreference returns null when nothing was ever saved', () async {
      expect(await service.getNotificationPreference('uid1'), isNull);
    });

    test('saveNotificationPreference then getNotificationPreference round-trips with '
        'the correct uid - not the literal doc id "settings"', () async {
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: true,
        tournamentUpdates: false,
        achievements: true,
        gameInvitations: false,
        allNotifications: true,
      ));

      final loaded = await service.getNotificationPreference('uid1');
      expect(loaded, isNotNull);
      // The bug this regression test guards against: fromFirestore used to
      // read uid from doc.id, which is always the literal string 'settings'
      // (notifications/{uid}/notificationPreferences/settings) - not the
      // real owner. A wrong uid here means a second save targets a bogus
      // path (notifications/settings/... instead of notifications/uid1/...).
      expect(loaded!.uid, 'uid1');
      expect(loaded.tournamentUpdates, isFalse);
      expect(loaded.gameInvitations, isFalse);
    });

    test('re-saving a loaded preference still writes under the real uid\'s path', () async {
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: true,
        tournamentUpdates: true,
        achievements: true,
        gameInvitations: true,
        allNotifications: true,
      ));

      // Simulates reopening the settings dialog (loads the saved
      // preference, including whatever uid it carries) and saving again.
      final reloaded = await service.getNotificationPreference('uid1');
      await service.saveNotificationPreference(NotificationPreference(
        uid: reloaded!.uid,
        friendRequests: reloaded.friendRequests,
        tournamentUpdates: false,
        achievements: reloaded.achievements,
        gameInvitations: reloaded.gameInvitations,
        allNotifications: reloaded.allNotifications,
      ));

      final bogusPathDoc = await firestore
          .collection('notifications')
          .doc('settings')
          .collection('notificationPreferences')
          .doc('settings')
          .get();
      expect(bogusPathDoc.exists, isFalse);

      final secondSave = await service.getNotificationPreference('uid1');
      expect(secondSave!.tournamentUpdates, isFalse);
    });

    test('getUserNotifications hides a disabled category', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Game invite',
        body: '...',
        type: 'game_invitation',
      );
      await service.sendNotification(
        uid: 'uid1',
        title: 'PvP challenge',
        body: '...',
        type: 'pvp_challenge',
      );
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: true,
        tournamentUpdates: true,
        achievements: true,
        gameInvitations: false,
        allNotifications: true,
      ));

      final notifications = await service.getUserNotifications('uid1');
      expect(notifications, isEmpty);
    });

    test('allNotifications: false hides every category regardless of its own toggle',
        () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Game invite',
        body: '...',
        type: 'game_invitation',
      );
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: true,
        tournamentUpdates: true,
        achievements: true,
        gameInvitations: true,
        allNotifications: false,
      ));

      expect(await service.getUserNotifications('uid1'), isEmpty);
    });

    test('an unrecognized notification type is shown by default', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Mystery',
        body: '...',
        type: 'something_new',
      );
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: false,
        tournamentUpdates: false,
        achievements: false,
        gameInvitations: false,
        allNotifications: true,
      ));

      final notifications = await service.getUserNotifications('uid1');
      expect(notifications, hasLength(1));
    });

    test('with no preference ever saved, every notification is shown', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Game invite',
        body: '...',
        type: 'game_invitation',
      );

      final notifications = await service.getUserNotifications('uid1');
      expect(notifications, hasLength(1));
    });

    test('a disabled category is also excluded from unreadOnly results', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'Game invite',
        body: '...',
        type: 'game_invitation',
      );
      await service.saveNotificationPreference(NotificationPreference(
        uid: 'uid1',
        friendRequests: true,
        tournamentUpdates: true,
        achievements: true,
        gameInvitations: false,
        allNotifications: true,
      ));

      final unread = await service.getUserNotifications('uid1', unreadOnly: true);
      expect(unread, isEmpty);
    });

    test('clearNotifications removes every notification for that user', () async {
      await service.sendNotification(
        uid: 'uid1',
        title: 'One',
        body: '...',
        type: 'game_invitation',
      );
      await service.sendNotification(
        uid: 'uid1',
        title: 'Two',
        body: '...',
        type: 'pvp_challenge',
      );

      await service.clearNotifications('uid1');

      expect(await service.getUserNotifications('uid1'), isEmpty);
    });
  });
}

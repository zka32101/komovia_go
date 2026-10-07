import 'dart:io' show Platform;

import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/notification.dart';
import 'package:komovia_go/models/user.dart';
import 'package:komovia_go/services/notification_service.dart';
import 'package:komovia_go/services/push_notification_service.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';

final _logger = Logger();

/// Notification Service プロバイダー
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// ユーザーの通知一覧
final userNotificationsProvider =
    FutureProvider.family<List<AppNotification>, String>(
  (ref, uid) async {
    _logger.i('Loading notifications for user: $uid');
    final service = ref.watch(notificationServiceProvider);

    try {
      final notifications = await service.getUserNotifications(uid);
      _logger.i('✅ Notifications loaded: ${notifications.length}');
      return notifications;
    } catch (e) {
      _logger.e('❌ Failed to load notifications: $e');
      rethrow;
    }
  },
);

/// 未読通知のみ
final unreadNotificationsProvider =
    FutureProvider.family<List<AppNotification>, String>(
  (ref, uid) async {
    _logger.i('Loading unread notifications');
    final service = ref.watch(notificationServiceProvider);

    try {
      final notifications =
          await service.getUserNotifications(uid, unreadOnly: true);
      _logger.i('✅ Unread notifications loaded: ${notifications.length}');
      return notifications;
    } catch (e) {
      _logger.e('❌ Failed to load unread: $e');
      rethrow;
    }
  },
);

/// 未読通知数
final unreadNotificationCountProvider =
    FutureProvider.family<int, String>((ref, uid) async {
  final unread = await ref.watch(unreadNotificationsProvider(uid).future);
  return unread.length;
});

/// 通知設定を取得
final notificationPreferenceProvider =
    FutureProvider.family<NotificationPreference?, String>(
  (ref, uid) async {
    _logger.i('Loading notification preference');
    final service = ref.watch(notificationServiceProvider);

    try {
      final preference = await service.getNotificationPreference(uid);
      return preference;
    } catch (e) {
      _logger.e('❌ Failed to load preference: $e');
      return null;
    }
  },
);

/// 通知を送信
final sendNotificationProvider = Provider<
    Future<String?> Function({
      required String uid,
      required String title,
      required String body,
      required String type,
      Map<String, dynamic>? data,
    })>((ref) {
  final service = ref.read(notificationServiceProvider);

  return ({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    _logger.i('Sending notification');
    try {
      final notificationId = await service.sendNotification(
        uid: uid,
        title: title,
        body: body,
        type: type,
        data: data,
      );
      _logger.i('✅ Notification sent');
      return notificationId;
    } catch (e) {
      _logger.e('❌ Failed to send notification: $e');
      rethrow;
    }
  };
});

/// 通知を既読に
final markNotificationAsReadProvider = Provider<
    Future<void> Function({
      required String uid,
      required String notificationId,
    })>((ref) {
  final service = ref.read(notificationServiceProvider);

  return ({
    required String uid,
    required String notificationId,
  }) async {
    _logger.i('Marking as read');
    try {
      await service.markAsRead(uid, notificationId);
      _logger.i('✅ Marked as read');
    } catch (e) {
      _logger.e('❌ Failed to mark as read: $e');
      rethrow;
    }
  };
});

/// FCM トークン登録
final registerFcmTokenProvider = Provider<
    Future<void> Function({
      required String uid,
      required String token,
      String? deviceName,
      String? platform,
    })>((ref) {
  final service = ref.read(notificationServiceProvider);

  return ({
    required String uid,
    required String token,
    String? deviceName,
    String? platform,
  }) async {
    _logger.i('Registering FCM token');
    try {
      await service.registerFcmToken(
        uid: uid,
        token: token,
        deviceName: deviceName,
        platform: platform,
      );
      _logger.i('✅ FCM token registered');
    } catch (e) {
      _logger.e('❌ Failed to register: $e');
      rethrow;
    }
  };
});

/// 通知設定を保存。komovia_core's NotificationPreference has no `uid` of
/// its own (see notification_service.dart's doc comments), so the owner
/// is passed alongside it here instead of being read off the model.
final saveNotificationPreferenceProvider = Provider<
    Future<void> Function(String uid, NotificationPreference)>((ref) {
  final service = ref.read(notificationServiceProvider);

  return (uid, preference) async {
    _logger.i('Saving preference');
    try {
      await service.saveNotificationPreference(uid, preference);
      _logger.i('✅ Preference saved');
    } catch (e) {
      _logger.e('❌ Failed to save: $e');
      rethrow;
    }
  };
});

/// 通知をクリア
final clearNotificationsProvider = Provider<
    Future<void> Function(String)>((ref) {
  final service = ref.read(notificationServiceProvider);

  return (uid) async {
    _logger.w('Clearing notifications');
    try {
      await service.clearNotifications(uid);
      _logger.i('✅ Cleared');
    } catch (e) {
      _logger.e('❌ Failed to clear: $e');
      rethrow;
    }
  };
});

/// Push Notification Service プロバイダー
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

/// Keeps the signed-in user's real FCM token registered in Firestore, and
/// keeps the in-app notification list/badge fresh when a push arrives while
/// the app is open, for as long as the app is running — the same
/// whole-app-lifetime pattern as purchaseRecoveryProvider
/// (lib/viewmodels/purchase_provider.dart). Watched once from GoEnApp.
final fcmSyncProvider = Provider<void>((ref) {
  final pushService = ref.watch(pushNotificationServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  Future<void> registerToken(String uid) async {
    try {
      final granted = await pushService.requestPermission();
      if (!granted) {
        _logger.w('Notification permission not granted for $uid');
        return;
      }
      final token = await pushService.getToken();
      if (token == null) return;
      await notificationService.registerFcmToken(
        uid: uid,
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _logger.i('✅ FCM token registered for $uid');
    } catch (e) {
      _logger.e('❌ Failed to register FCM token: $e');
    }
  }

  String? currentUid() => ref.read(authStateProvider).valueOrNull?.uid;

  final initialUid = currentUid();
  if (initialUid != null) {
    registerToken(initialUid);
  }

  ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
    final uid = next.valueOrNull?.uid;
    if (uid != null && uid != previous?.valueOrNull?.uid) {
      registerToken(uid);
    }
  });

  final tokenSub = pushService.onTokenRefresh.listen((token) {
    final uid = currentUid();
    if (uid == null) return;
    notificationService.registerFcmToken(
      uid: uid,
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  });

  final messageSub = pushService.onForegroundMessage.listen((_) {
    final uid = currentUid();
    if (uid == null) return;
    // The Cloud Function that actually sends the push (triggered by the
    // same notifications/{uid}/messages/{id} Firestore doc NotificationService
    // already writes for every notification type) doesn't show a
    // system-tray banner while the app is foregrounded, so refresh the
    // in-app list/badge instead of leaving them stale until some
    // unrelated rebuild happens to re-fetch them.
    ref.invalidate(userNotificationsProvider(uid));
    ref.invalidate(unreadNotificationsProvider(uid));
    ref.invalidate(unreadNotificationCountProvider(uid));
  });

  ref.onDispose(() {
    tokenSub.cancel();
    messageSub.cancel();
  });
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/notification.dart'
    show AppNotificationFirestore, notificationFromFirestore;

final _logger = Logger();

/// komovia_core's `NotificationPreference` has no `uid` field of its own
/// (it's a pure settings value) - the owning uid comes from the Firestore
/// path (`notifications/{uid}/notificationPreferences/settings`, whose
/// doc id is always the literal string 'settings', never a real uid) and
/// is carried alongside the preference by this service's callers instead.
extension _NotificationPreferenceFirestore on NotificationPreference {
  Map<String, dynamic> toFirestore() => toJson();
}

NotificationPreference _preferenceFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc) {
  return NotificationPreference.fromJson(doc.data() ?? const {});
}

/// 通知サービス (FCM + Firestore統合)
class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String notificationsCollection = 'notifications';
  static const String fcmTokensCollection = 'fcmTokens';
  static const String preferencesCollection = 'notificationPreferences';

  /// 通知を送信（保存）
  Future<String?> sendNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.i('Sending notification to user: $uid');

      final docRef = _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection('messages')
          .doc();

      final notification = AppNotification(
        id: docRef.id,
        uid: uid,
        title: title,
        body: body,
        data: data,
        type: type,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await docRef.set(notification.toFirestore());
      _logger.i('✅ Notification sent: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error sending notification: $e');
      rethrow;
    }
  }

  /// ユーザーの通知一覧
  ///
  /// A sender can't read the recipient's own notification preferences
  /// (firestore.rules only lets the owner read
  /// notifications/{uid}/notificationPreferences/*), so disabled
  /// categories can't be stopped at send time - filtering has to happen
  /// here, on the read side, instead. This runs after the `limit` above,
  /// so a user with many disabled-category notifications among their most
  /// recent `limit` could see fewer than `limit` results even when older
  /// enabled ones exist - an accepted, documented tradeoff rather than a
  /// multi-page fetch loop for what's a notification list, not a feed
  /// that needs to always fill the page.
  Future<List<AppNotification>> getUserNotifications(
    String uid, {
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      _logger.i('Fetching notifications for user: $uid');

      var query = _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final snapshot = await query.get();
      final notifications = snapshot.docs
          .map((doc) => notificationFromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      final preference = await getNotificationPreference(uid);
      final visible = preference == null
          ? notifications
          : notifications.where((n) => preference.allows(n.type)).toList();

      _logger.i('✅ Notifications fetched: ${visible.length}');
      return visible;
    } catch (e) {
      _logger.e('Error fetching notifications: $e');
      rethrow;
    }
  }

  /// 通知を既読に
  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      _logger.i('Marking notification as read');

      await _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection('messages')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': Timestamp.now(),
      });

      _logger.i('✅ Notification marked as read');
    } catch (e) {
      _logger.e('Error marking as read: $e');
      rethrow;
    }
  }

  /// FCM トークンを登録
  Future<void> registerFcmToken({
    required String uid,
    required String token,
    String? deviceName,
    String? platform,
  }) async {
    try {
      _logger.i('Registering FCM token');

      await _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection(fcmTokensCollection)
          .doc(token)
          .set({
        'uid': uid,
        'deviceName': deviceName,
        'platform': platform,
        'registeredAt': Timestamp.now(),
      });

      _logger.i('✅ FCM token registered');
    } catch (e) {
      _logger.e('Error registering FCM token: $e');
      rethrow;
    }
  }

  /// 通知設定を取得
  Future<NotificationPreference?> getNotificationPreference(
      String uid) async {
    try {
      _logger.i('Fetching notification preference');

      final doc = await _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection(preferencesCollection)
          .doc('settings')
          .get();

      if (!doc.exists) {
        return null;
      }

      return _preferenceFromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching preference: $e');
      rethrow;
    }
  }

  /// 通知設定を保存
  Future<void> saveNotificationPreference(
    String uid,
    NotificationPreference preference,
  ) async {
    try {
      _logger.i('Saving notification preference');

      await _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection(preferencesCollection)
          .doc('settings')
          .set(preference.toFirestore());

      _logger.i('✅ Preference saved');
    } catch (e) {
      _logger.e('Error saving preference: $e');
      rethrow;
    }
  }

  /// 通知をクリア
  Future<void> clearNotifications(String uid) async {
    try {
      _logger.w('Clearing all notifications for user: $uid');

      final snapshot = await _firestore
          .collection(notificationsCollection)
          .doc(uid)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.i('✅ Notifications cleared');
    } catch (e) {
      _logger.e('Error clearing notifications: $e');
      rethrow;
    }
  }
}

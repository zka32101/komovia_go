import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import '../services/firestore_time.dart';

// `AppNotification`/`NotificationPreference` used to be declared here with
// their own Firestore-coupled shape, but that shape has been ported to
// `package:komovia_core` - re-exported below unchanged so every existing
// `import 'package:komovia_go/models/notification.dart';` keeps working.
//
// komovia_core's `NotificationPreference` has no `uid` field (it's a pure
// per-category settings value with no identity of its own) - callers that
// used to read `preference.uid` now carry the uid alongside it instead
// (see `NotificationService.saveNotificationPreference`'s signature).
export 'package:komovia_core/komovia_core.dart'
    show AppNotification, NotificationPreference;

/// `AppNotification` has no storage dependency (see komovia_core's doc
/// comments) - converting to/from Firestore's `DocumentSnapshot`/
/// `Timestamp` is each app's own responsibility. Public (not confined to
/// notification_service.dart) since correspondence_game_service.dart/
/// team_game_service.dart also construct and persist one directly.
extension AppNotificationFirestore on AppNotification {
  Map<String, dynamic> toFirestore() {
    final json = toJson()..remove('id');
    json['createdAt'] = Timestamp.fromDate(createdAt);
    json['readAt'] = readAt != null ? Timestamp.fromDate(readAt!) : null;
    return json;
  }
}

AppNotification notificationFromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return AppNotification.fromJson({
    ...data,
    'id': doc.id,
    'createdAt': isoFromTimestamp(data['createdAt']),
    'readAt': isoFromTimestamp(data['readAt']),
  });
}

/// FCM トークンの登録
///
/// App-specific (push-notification plumbing, not a game-agnostic concept)
/// - kept here rather than ported to komovia_core.
class FcmToken {
  final String uid;
  final String token;
  final String? deviceName;
  final String? platform; // 'ios', 'android', 'web'
  final DateTime registeredAt;
  final DateTime? lastUsedAt;

  FcmToken({
    required this.uid,
    required this.token,
    this.deviceName,
    this.platform,
    required this.registeredAt,
    this.lastUsedAt,
  });

  factory FcmToken.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FcmToken(
      uid: data['uid'] ?? '',
      token: doc.id,
      deviceName: data['deviceName'],
      platform: data['platform'],
      registeredAt: dateTimeFromTimestamp(data['registeredAt'], DateTime.now()),
      lastUsedAt: dateTimeFromTimestampOrNull(data['lastUsedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'deviceName': deviceName,
      'platform': platform,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'lastUsedAt':
          lastUsedAt != null ? Timestamp.fromDate(lastUsedAt!) : null,
    };
  }

  @override
  String toString() => 'FcmToken(uid: $uid, platform: $platform)';
}

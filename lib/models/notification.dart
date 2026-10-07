import 'package:cloud_firestore/cloud_firestore.dart';

/// アプリ内通知
class AppNotification {
  final String id;
  final String uid;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String type; // 'friend_request', 'tournament_match', 'achievement', etc.
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    this.data,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppNotification(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: data['data'] as Map<String, dynamic>?,
      type: data['type'] ?? 'general',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      readAt: data['readAt'] is Timestamp
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'title': title,
      'body': body,
      'data': data,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  AppNotification copyWith({
    String? id,
    String? uid,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  @override
  String toString() => 'AppNotification(id: $id, type: $type)';
}

/// FCM トークンの登録
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
      registeredAt: data['registeredAt'] is Timestamp
          ? (data['registeredAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastUsedAt: data['lastUsedAt'] is Timestamp
          ? (data['lastUsedAt'] as Timestamp).toDate()
          : null,
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

/// 通知設定
class NotificationPreference {
  final String uid;
  final bool friendRequests;
  final bool tournamentUpdates;
  final bool achievements;
  final bool gameInvitations;
  final bool allNotifications;

  NotificationPreference({
    required this.uid,
    required this.friendRequests,
    required this.tournamentUpdates,
    required this.achievements,
    required this.gameInvitations,
    required this.allNotifications,
  });

  /// [uid] is passed in by the caller rather than read from [doc.id] -
  /// every preference doc's own id is the constant string 'settings'
  /// (nested under notifications/{uid}/notificationPreferences/settings),
  /// not the owning user's uid, so reading uid from doc.id always produced
  /// the literal string 'settings' instead of a real uid.
  factory NotificationPreference.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data()!;
    return NotificationPreference(
      uid: uid,
      friendRequests: data['friendRequests'] ?? true,
      tournamentUpdates: data['tournamentUpdates'] ?? true,
      achievements: data['achievements'] ?? true,
      gameInvitations: data['gameInvitations'] ?? true,
      allNotifications: data['allNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'friendRequests': friendRequests,
      'tournamentUpdates': tournamentUpdates,
      'achievements': achievements,
      'gameInvitations': gameInvitations,
      'allNotifications': allNotifications,
    };
  }

  @override
  String toString() =>
      'NotificationPreference(uid: $uid, all: $allNotifications)';
}

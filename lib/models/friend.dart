import 'package:cloud_firestore/cloud_firestore.dart';

/// 友達リスト エントリ
class Friend {
  final String uid;
  final String friendUid;
  final String displayName;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final bool isBlocked;

  Friend({
    required this.uid,
    required this.friendUid,
    required this.displayName,
    required this.addedAt,
    this.lastPlayedAt,
    required this.isBlocked,
  });

  factory Friend.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Friend(
      uid: data['uid'] ?? '',
      friendUid: doc.id,
      displayName: data['displayName'] ?? 'Friend',
      addedAt: data['addedAt'] is Timestamp
          ? (data['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastPlayedAt: data['lastPlayedAt'] is Timestamp
          ? (data['lastPlayedAt'] as Timestamp).toDate()
          : null,
      isBlocked: data['isBlocked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'addedAt': Timestamp.fromDate(addedAt),
      'lastPlayedAt':
          lastPlayedAt != null ? Timestamp.fromDate(lastPlayedAt!) : null,
      'isBlocked': isBlocked,
    };
  }

  Friend copyWith({
    String? uid,
    String? friendUid,
    String? displayName,
    DateTime? addedAt,
    DateTime? lastPlayedAt,
    bool? isBlocked,
  }) {
    return Friend(
      uid: uid ?? this.uid,
      friendUid: friendUid ?? this.friendUid,
      displayName: displayName ?? this.displayName,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  @override
  String toString() => 'Friend(uid: $uid, friendUid: $friendUid)';
}

/// 友達リクエスト
class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String fromDisplayName;
  final DateTime sentAt;
  final bool isAccepted;
  final bool isRejected;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromDisplayName,
    required this.sentAt,
    required this.isAccepted,
    required this.isRejected,
  });

  factory FriendRequest.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FriendRequest(
      id: doc.id,
      fromUid: data['fromUid'] ?? '',
      toUid: data['toUid'] ?? '',
      fromDisplayName: data['fromDisplayName'] ?? 'User',
      sentAt: data['sentAt'] is Timestamp
          ? (data['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      isAccepted: data['isAccepted'] ?? false,
      isRejected: data['isRejected'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'fromDisplayName': fromDisplayName,
      'sentAt': Timestamp.fromDate(sentAt),
      'isAccepted': isAccepted,
      'isRejected': isRejected,
    };
  }

  @override
  String toString() =>
      'FriendRequest(id: $id, from: $fromUid, to: $toUid)';
}

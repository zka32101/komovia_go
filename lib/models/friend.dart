import 'package:cloud_firestore/cloud_firestore.dart';

// `Friend` used to be declared here with its own uid/friendUid/addedAt/
// isBlocked shape, but it was never actually wired to any working service
// (see the old friend_provider.dart) - the shape FriendService/
// friends_screen.dart really used was extended_game_models.dart's freezed
// `Friend` (uid/displayName/status/addedAt/notes/avatarUrl/requestedBy).
//
// Both have now been replaced by `package:komovia_core`'s `Friendship`
// (uid/friendUid/displayName/status/requestedBy/blockedBy/addedAt/
// lastPlayedAt), a game-agnostic port of the same concept shared across
// Komovia's game apps - callers import it directly from komovia_core
// (`import 'package:komovia_core/komovia_core.dart';`) rather than via
// this file, so it's clear at a glance which type is the shared core one.
//
// `notes`/`avatarUrl` existed on the old extended_game_models.dart `Friend`
// but have no equivalent on `Friendship` - the per-friend notes feature
// (an editable note shown on the friend list/profile) has been dropped
// rather than kept as an app-local side channel; see FriendService's own
// doc comments for details. `isBlocked` is superseded by `status ==
// 'blocked'`.

/// 友達リクエスト
///
/// Firestore-coupled and app-specific (unlike `Friendship`, which has no
/// storage dependency) - kept here rather than ported to komovia_core.
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
  String toString() => 'FriendRequest(id: $id, from: $fromUid, to: $toUid)';
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/extended_game_models.dart';

final _logger = Logger();

/// Service for managing friend relationships
class FriendService {
  final FirebaseFirestore _firestore;

  FriendService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Reference to a user's own entry for a given friend, on either side of
  /// the relationship (`users/{uid}/friends/{otherUid}`).
  DocumentReference<Map<String, dynamic>> _friendDoc(String uid, String otherUid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(otherUid);
  }

  /// Looks up a user's display name to denormalize onto a friend-relationship
  /// doc - Friend.fromJson requires displayName, but the relationship
  /// document itself only ever stores a uid, so this has to be fetched from
  /// the user's own profile at write time.
  Future<String> _lookupDisplayName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['displayName'] as String? ?? 'Unknown';
  }

  /// Add a friend (sends pending request).
  ///
  /// Friendship is denormalized into both users' own `friends`
  /// subcollections so each user's queries (getFriends/getPendingRequests/
  /// isFriend) only ever need to read their own data - so both sides get a
  /// 'pending' entry here, not just the sender's.
  ///
  /// Refuses (returns false, writes nothing) if a relationship already
  /// exists as 'accepted' or 'blocked' - without this guard, re-running
  /// this against an existing accepted friend (e.g. a stale search result
  /// still showing "追加") would silently reset both sides back to
  /// 'pending', breaking an accepted friendship. Re-sending while already
  /// 'pending' is harmless and still allowed (just refreshes addedAt).
  Future<bool> addFriend({
    required String currentUid,
    required String friendUid,
    String? notes,
  }) async {
    try {
      final existingStatus = await getFriendStatus(currentUid: currentUid, friendUid: friendUid);
      if (existingStatus == 'accepted' || existingStatus == 'blocked') {
        _logger.i('addFriend no-op: $friendUid is already $existingStatus for $currentUid');
        return false;
      }

      _logger.i('Adding friend: $friendUid to user: $currentUid');

      // Friend.fromJson parses addedAt via DateTime.parse(json['addedAt']
      // as String) - a raw DateTime would round-trip through Firestore as
      // a Timestamp instead and fail that cast on every later read.
      final now = DateTime.now().toIso8601String();
      final friendDisplayName = await _lookupDisplayName(friendUid);
      final currentDisplayName = await _lookupDisplayName(currentUid);
      final batch = _firestore.batch();

      // If this is a resend of an already-pending request, keep the
      // original sender so the UI's incoming/outgoing split doesn't flip
      // depending on who happens to trigger the resend.
      String requestedBy = currentUid;
      if (existingStatus == 'pending') {
        final existingData = (await _friendDoc(currentUid, friendUid).get()).data();
        requestedBy = existingData?['requestedBy'] as String? ?? currentUid;
      }

      batch.set(_friendDoc(currentUid, friendUid), {
        'uid': friendUid,
        'displayName': friendDisplayName,
        'status': 'pending',
        'addedAt': now,
        'notes': notes ?? '',
        'requestedBy': requestedBy,
      });
      batch.set(_friendDoc(friendUid, currentUid), {
        'uid': currentUid,
        'displayName': currentDisplayName,
        'status': 'pending',
        'addedAt': now,
        'notes': '',
        'requestedBy': requestedBy,
      });

      await batch.commit();

      return true;
    } catch (e) {
      _logger.e('Failed to add friend: $e');
      return false;
    }
  }

  /// Accept friend request - marks both sides' entries as accepted.
  Future<bool> acceptFriendRequest({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      _logger.i('Accepting friend request from: $friendUid');

      final batch = _firestore.batch();
      batch.set(
        _friendDoc(currentUid, friendUid),
        {'uid': friendUid, 'status': 'accepted'},
        SetOptions(merge: true),
      );
      batch.set(
        _friendDoc(friendUid, currentUid),
        {'uid': currentUid, 'status': 'accepted'},
        SetOptions(merge: true),
      );
      await batch.commit();

      return true;
    } catch (e) {
      _logger.e('Failed to accept friend request: $e');
      return false;
    }
  }

  /// Reject a pending friend request - removes both sides' pending entries
  /// so the sender is free to send a new request later, same as if there'd
  /// never been one. This is distinct from blocking (which is a lasting
  /// decision); also used for the sender's own "cancel request" action,
  /// since canceling a request you sent is the same data operation as the
  /// recipient declining it.
  ///
  /// Refuses (no-op) unless the relationship is actually 'pending' on the
  /// caller's own side, so a stale UI can't use this to delete an already
  /// -accepted friendship.
  Future<bool> rejectFriendRequest({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final status = await getFriendStatus(currentUid: currentUid, friendUid: friendUid);
      if (status != 'pending') {
        _logger.i('rejectFriendRequest no-op: $friendUid is $status for $currentUid, not pending');
        return false;
      }

      _logger.i('Rejecting friend request with: $friendUid');

      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, friendUid));
      batch.delete(_friendDoc(friendUid, currentUid));
      await batch.commit();

      return true;
    } catch (e) {
      _logger.e('Failed to reject friend request: $e');
      return false;
    }
  }

  /// Block a user. Blocking should work even for someone who was never
  /// actually a friend, so the caller's own entry is a full upsert rather
  /// than requiring one to already exist (a bare merge-update would leave
  /// required fields like displayName/addedAt missing on a brand-new doc,
  /// breaking every later read via getFriends/getBlockedUsers).
  ///
  /// Also mirrors the block onto the target's own entry, if they already
  /// have one - otherwise a blocked former friend would keep reading
  /// 'accepted' on their own side (friendsStreamProvider/getFriends would
  /// still list the blocker as an accepted friend to them, and the UI's
  /// message/invite buttons - only ever shown for an accepted friend -
  /// would stay reachable in that direction too). The mirror is skipped
  /// if the target's entry is already 'blocked' for any reason, so this
  /// never overwrites a block the target placed independently; `blockedBy`
  /// records who actually caused each entry's blocked state, so
  /// unblockFriend can tell its own mirror apart from that independent
  /// block later.
  Future<bool> blockFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      _logger.i('Blocking friend: $friendUid');

      final ref = _friendDoc(currentUid, friendUid);
      final existing = (await ref.get()).data();

      await ref.set({
        'uid': friendUid,
        'displayName':
            existing?['displayName'] as String? ?? await _lookupDisplayName(friendUid),
        'status': 'blocked',
        'addedAt': existing?['addedAt'] ?? DateTime.now().toIso8601String(),
        'notes': existing?['notes'] ?? '',
        'blockedBy': currentUid,
      });

      final otherRef = _friendDoc(friendUid, currentUid);
      final otherDoc = await otherRef.get();
      if (otherDoc.exists && otherDoc.data()?['status'] != 'blocked') {
        await otherRef.update({'status': 'blocked', 'blockedBy': currentUid});
      }

      return true;
    } catch (e) {
      _logger.e('Failed to block friend: $e');
      return false;
    }
  }

  /// Unblock a user - removes the block on the caller's own side.
  ///
  /// This intentionally does NOT force both sides back to 'accepted': the
  /// block overwrote whatever relationship existed before (if any), so
  /// there's no reliable prior state to restore, and forcing a friendship
  /// that may never have existed would also be rejected by firestore.rules'
  /// create rule (which only allows a brand-new entry with status
  /// 'pending'). Removing the block returns the caller to "no relationship"
  /// with this user - they can send a fresh friend request if they want to
  /// actually become friends again.
  ///
  /// Also removes the mirror blockFriend placed on the target's own entry
  /// - but only when `blockedBy` shows THIS block caused it; if the target
  /// independently blocked back (their own `blockedBy` is their own uid),
  /// that block is left alone, since only they can lift it.
  Future<bool> unblockFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      _logger.i('Unblocking friend: $friendUid');

      await _friendDoc(currentUid, friendUid).delete();

      final otherRef = _friendDoc(friendUid, currentUid);
      final otherDoc = await otherRef.get();
      if (otherDoc.exists &&
          otherDoc.data()?['status'] == 'blocked' &&
          otherDoc.data()?['blockedBy'] == currentUid) {
        await otherRef.delete();
      }

      return true;
    } catch (e) {
      _logger.e('Failed to unblock friend: $e');
      return false;
    }
  }

  /// Remove friend - both sides, so neither user is left with a stale
  /// mirror entry pointing at a friendship the other side ended.
  Future<bool> removeFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      _logger.i('Removing friend: $friendUid');

      final batch = _firestore.batch();
      batch.delete(_friendDoc(currentUid, friendUid));
      batch.delete(_friendDoc(friendUid, currentUid));
      await batch.commit();

      return true;
    } catch (e) {
      _logger.e('Failed to remove friend: $e');
      return false;
    }
  }

  /// Get friends list
  Future<List<Friend>> getFriends({
    required String uid,
    String status = 'accepted',
  }) async {
    try {
      _logger.i('Getting friends for user: $uid with status: $status');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('friends')
          .where('status', isEqualTo: status)
          .get();

      final friends = querySnapshot.docs
          .map((doc) => Friend.fromJson({...doc.data(), 'uid': doc.id}))
          .toList();

      return friends;
    } catch (e) {
      _logger.e('Failed to get friends: $e');
      return [];
    }
  }

  /// Get pending friend requests
  Future<List<Friend>> getPendingRequests({required String uid}) async {
    try {
      _logger.i('Getting pending friend requests for: $uid');

      return await getFriends(uid: uid, status: 'pending');
    } catch (e) {
      _logger.e('Failed to get pending requests: $e');
      return [];
    }
  }

  /// Get blocked users
  Future<List<Friend>> getBlockedUsers({required String uid}) async {
    try {
      _logger.i('Getting blocked users for: $uid');

      return await getFriends(uid: uid, status: 'blocked');
    } catch (e) {
      _logger.e('Failed to get blocked users: $e');
      return [];
    }
  }

  /// Check if user is friend
  Future<bool> isFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    final status = await getFriendStatus(currentUid: currentUid, friendUid: friendUid);
    return status == 'accepted';
  }

  /// Raw relationship status on currentUid's own side ('pending',
  /// 'accepted', 'blocked'), or null if no relationship doc exists at all.
  Future<String?> getFriendStatus({
    required String currentUid,
    required String friendUid,
  }) async {
    try {
      final doc = await _friendDoc(currentUid, friendUid).get();
      if (!doc.exists) return null;
      return doc.data()?['status'] as String?;
    } catch (e) {
      _logger.e('Failed to check friend status: $e');
      return null;
    }
  }

  /// Update friend notes
  Future<bool> updateFriendNotes({
    required String currentUid,
    required String friendUid,
    required String notes,
  }) async {
    try {
      _logger.i('Updating friend notes for: $friendUid');

      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update({'notes': notes});

      return true;
    } catch (e) {
      _logger.e('Failed to update friend notes: $e');
      return false;
    }
  }

  /// Stream friends list (real-time)
  Stream<List<Friend>> streamFriends({
    required String uid,
    String status = 'accepted',
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Friend.fromJson({...doc.data(), 'uid': doc.id}))
          .toList();
    });
  }

  /// Search for users to add as friends
  Future<List<UserProfile>> searchUsers({required String query}) async {
    try {
      _logger.i('Searching for users: $query');

      final querySnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '${query}z')
          .limit(10)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserProfile.fromJson({...doc.data(), 'uid': doc.id}))
          .toList();

      return users;
    } catch (e) {
      _logger.e('Failed to search users: $e');
      return [];
    }
  }
}

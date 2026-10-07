import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart';
import '../models/extended_game_models.dart';
import 'package:komovia_core/komovia_core.dart';
import '../models/pvp_game.dart';
import '../services/friend_service.dart';
import '../services/game_invitation_service.dart';
import 'notification_provider.dart';
import 'pvp_game_provider.dart';

// ==================== Service Providers ====================

/// Friend Service Provider
final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

/// Game Invitation Service Provider
final gameInvitationServiceProvider = Provider<GameInvitationService>((ref) {
  return GameInvitationService();
});

// Note: leaderboard providers used to live here, backed by a
// `LeaderboardService` API (getTopPlayers/getPlayerRank/streamLeaderboard/
// etc.) that no longer exists — `services/leaderboard_service.dart` was
// replaced by Phase 58's leaderboard system with a different API
// (getLeaderboard/getUserRank/updateLeaderboard/...). Those calls were
// dead code (nothing in lib/views referenced them) and didn't compile, so
// they were removed; use `leaderboard_provider.dart` instead.

// ==================== Friend System Providers ====================

/// Get current user's accepted friends
final acceptedFriendsProvider = FutureProvider.family<List<Friendship>, String>(
  (ref, uid) async {
    final service = ref.watch(friendServiceProvider);
    return service.getFriends(uid: uid, status: 'accepted');
  },
);

/// Get current user's blocked users list.
///
/// FriendsScreen used to build this inline (a fresh anonymous
/// FutureProvider constructed on every build()), which never converges:
/// each instance resolves, triggers a rebuild, which constructs yet
/// another fresh instance, forever - an actual busy-rebuild loop, not
/// just a style nit. A stable family provider fixes that, same pattern
/// as pendingFriendRequestsProvider below.
final blockedFriendsProvider = FutureProvider.family<List<Friendship>, String>(
  (ref, uid) async {
    final service = ref.watch(friendServiceProvider);
    return service.getBlockedUsers(uid: uid);
  },
);

/// Get current user's pending friend requests
final pendingFriendRequestsProvider =
    FutureProvider.family<List<Friendship>, String>(
  (ref, uid) async {
    final service = ref.watch(friendServiceProvider);
    return service.getPendingRequests(uid: uid);
  },
);

/// Stream friend list (real-time)
final friendsStreamProvider = StreamProvider.family<List<Friendship>, String>(
  (ref, uid) {
    final service = ref.watch(friendServiceProvider);
    return service.streamFriends(uid: uid, status: 'accepted');
  },
);

/// Add friend provider. [fromDisplayName] is the sender's own display name
/// (the caller already has it from currentUserProvider, same as
/// sendGameInvitationProvider's fromDisplayName param) - used only for the
/// friend_request notification sent to the recipient on success.
final addFriendProvider =
    FutureProvider.family<bool, (String, String, String, String?)>(
  (ref, params) async {
    final (currentUid, friendUid, fromDisplayName, notes) = params;
    final service = ref.watch(friendServiceProvider);
    final success = await service.addFriend(
      currentUid: currentUid,
      friendUid: friendUid,
      notes: notes,
    );

    if (success) {
      try {
        await ref.read(sendNotificationProvider)(
          uid: friendUid,
          title: '$fromDisplayNameさんからフレンド申請が届きました',
          body: '「フレンド」→「招待待ち」タブで確認できます',
          type: 'friend_request',
        );
      } catch (e) {
        // Best-effort, same as every other cross-user notification in
        // this app (e.g. sendGameInvitationProvider's game_invitation).
      }
    }

    return success;
  },
);

/// Accept friend request provider
final acceptFriendRequestProvider =
    FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (currentUid, friendUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.acceptFriendRequest(
      currentUid: currentUid,
      friendUid: friendUid,
    );
  },
);

/// Reject a pending friend request provider - used both for the recipient
/// declining it and the sender canceling it (same underlying operation).
final rejectFriendRequestProvider =
    FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (currentUid, friendUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.rejectFriendRequest(currentUid: currentUid, friendUid: friendUid);
  },
);

/// Block friend provider
final blockFriendProvider = FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (currentUid, friendUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.blockFriend(currentUid: currentUid, friendUid: friendUid);
  },
);

/// Unblock friend provider
final unblockFriendProvider = FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (currentUid, friendUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.unblockFriend(currentUid: currentUid, friendUid: friendUid);
  },
);

/// Search users provider
final searchUsersProvider = FutureProvider.family<List<UserProfile>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];
    final service = ref.watch(friendServiceProvider);
    return service.searchUsers(query: query);
  },
);

// ==================== Game Invitation Providers ====================

/// Get incoming game invitations
final incomingInvitationsProvider =
    FutureProvider.family<List<GameInvitation>, String>(
  (ref, uid) async {
    final service = ref.watch(gameInvitationServiceProvider);
    return service.getIncomingInvitations(uid: uid);
  },
);

/// Get outgoing game invitations
final outgoingInvitationsProvider =
    FutureProvider.family<List<GameInvitation>, String>(
  (ref, uid) async {
    final service = ref.watch(gameInvitationServiceProvider);
    return service.getOutgoingInvitations(uid: uid);
  },
);

/// Stream incoming invitations (real-time). Fires the opportunistic
/// expired-invitation cleanup once per subscription (fire-and-forget,
/// never blocks the stream) since there's no scheduler to run it
/// otherwise - see cleanupExpiredInvitationsProvider.
final incomingInvitationsStreamProvider =
    StreamProvider.family<List<GameInvitation>, String>(
  (ref, uid) {
    final service = ref.watch(gameInvitationServiceProvider);
    ref.read(cleanupExpiredInvitationsProvider)(uid);
    return service.streamIncomingInvitations(uid: uid);
  },
);

/// Send a game invitation. A plain action Provider (not
/// FutureProvider.family) since sending is a one-shot action, not a cached
/// query - a family keyed by the full params record would otherwise grow
/// one cache entry per invitation ever sent.
final sendGameInvitationProvider = Provider((ref) {
  final service = ref.watch(gameInvitationServiceProvider);
  return ({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required int boardSize,
    String? customMessage,
  }) async {
    final success = await service.sendInvitation(
      fromUid: fromUid,
      fromDisplayName: fromDisplayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      boardSize: boardSize,
      customMessage: customMessage,
    );

    if (success) {
      try {
        await ref.read(sendNotificationProvider)(
          uid: toUid,
          title: '$fromDisplayNameさんから対局の招待が届きました',
          body: '「フレンド」→「対局の招待」タブで確認できます',
          type: 'game_invitation',
        );
      } catch (e) {
        // Best-effort, same as every other cross-user notification in
        // this app (e.g. matching_screen.dart's pvp_challenge) - the
        // invitation itself is already saved either way.
      }
    }

    return success;
  };
});

/// Accepts a pending invitation and, if that succeeded, creates the actual
/// PvP game (inviter plays black, matching the "founder plays black"
/// convention used elsewhere - e.g. matching_screen.dart's _startGame) by
/// routing through createPvpGameProvider so a game started this way gets
/// the same live-spectator-session wiring any other PvP game gets.
/// Returns null if the invitation couldn't be accepted (already
/// accepted/declined by the time this ran, or expired).
final acceptGameInvitationProvider = Provider((ref) {
  return (GameInvitation invitation) async {
    final service = ref.watch(gameInvitationServiceProvider);
    final accepted = await service.acceptInvitation(invitationId: invitation.id);
    if (accepted == null) return null;

    final PvpGame game = await ref.read(createPvpGameProvider)(
      accepted.boardSize,
      accepted.fromUid,
      accepted.fromDisplayName,
      accepted.toUid,
      accepted.toDisplayName,
    );
    return game;
  };
});

/// Decline a pending invitation.
final declineGameInvitationProvider = Provider((ref) {
  final service = ref.watch(gameInvitationServiceProvider);
  return (String invitationId) => service.declineInvitation(invitationId: invitationId);
});

/// Opportunistic housekeeping: deletes [uid]'s own expired pending
/// invitations. There's no Cloud Functions scheduler in this app, so this
/// is meant to be fired (best-effort, fire-and-forget) whenever [uid]'s
/// invitations are loaded rather than on a schedule - see
/// GameInvitationService.cleanupExpiredInvitations.
final cleanupExpiredInvitationsProvider = Provider((ref) {
  final service = ref.watch(gameInvitationServiceProvider);
  return (String uid) => service.cleanupExpiredInvitations(uid: uid);
});

// ==================== Computed Providers ====================

/// Check if users are friends
final isFriendProvider = FutureProvider.family<bool, (String, String)>(
  (ref, params) async {
    final (currentUid, targetUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.isFriend(currentUid: currentUid, friendUid: targetUid);
  },
);

/// Raw relationship status ('pending'/'accepted'/'blocked'), or null if no
/// relationship exists yet - used to decide what a "add friend" search
/// result should actually show/allow instead of always offering "追加"
/// (which would otherwise let re-tapping it reset an accepted friendship
/// back to pending, see FriendService.addFriend's guard).
final friendStatusProvider = FutureProvider.family<String?, (String, String)>(
  (ref, params) async {
    final (currentUid, targetUid) = params;
    final service = ref.watch(friendServiceProvider);
    return service.getFriendStatus(currentUid: currentUid, friendUid: targetUid);
  },
);

/// Get user profile (for friend display)
final userProfileProvider = FutureProvider.family<UserProfile?, String>(
  (ref, uid) async {
    final firestore = FirebaseFirestore.instance;
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromJson({...doc.data()!, 'uid': doc.id});
    } catch (e) {
      return null;
    }
  },
);


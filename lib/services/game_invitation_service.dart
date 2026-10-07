import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/extended_game_models.dart';

final _logger = Logger();

/// Service for managing game invitations (friend-to-friend PvP invites,
/// distinct from the open per-game chat_messages/matching_queue systems).
class GameInvitationService {
  final FirebaseFirestore _firestore;

  GameInvitationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('gameInvitations');

  /// Send a game invitation.
  Future<bool> sendInvitation({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required int boardSize,
    String gameMode = 'standard',
    String? customMessage,
    Duration expirationTime = const Duration(days: 7),
  }) async {
    try {
      // FriendService.blockFriend mirrors a block onto both sides' own
      // `friends` entries, so checking the sender's own (readable) entry
      // catches a block placed by either party.
      final relationship = await _firestore
          .collection('users')
          .doc(fromUid)
          .collection('friends')
          .doc(toUid)
          .get();
      if (relationship.data()?['status'] == 'blocked') {
        _logger.w('sendInvitation refused: $fromUid/$toUid have a blocked relationship');
        return false;
      }

      _logger.i('Sending game invitation from $fromUid to $toUid');

      final now = DateTime.now();
      final expiresAt = now.add(expirationTime);
      final invitationId = _invitations.doc().id;

      // GameInvitation.fromJson parses createdAt/expiresAt via
      // DateTime.parse(json[...] as String) - storing raw DateTimes would
      // round-trip through Firestore as Timestamps and fail that cast on
      // every later read.
      await _invitations.doc(invitationId).set({
        'id': invitationId,
        'fromUid': fromUid,
        'fromDisplayName': fromDisplayName,
        'toUid': toUid,
        'toDisplayName': toDisplayName,
        'gameMode': gameMode,
        'boardSize': boardSize,
        'createdAt': now.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'status': 'pending',
        'customMessage': customMessage ?? '',
      });

      return true;
    } catch (e) {
      _logger.e('Failed to send invitation: $e');
      return false;
    }
  }

  /// Accepts a pending invitation. Returns the now-accepted invitation, or
  /// null if it wasn't pending anymore (already accepted/declined, or this
  /// call lost a race with another accept/decline/cancel) - the transaction
  /// guard means a double-tap can never flip it twice, which matters to the
  /// caller since accepting is what triggers creating the actual game.
  Future<GameInvitation?> acceptInvitation({required String invitationId}) async {
    try {
      return await _firestore.runTransaction<GameInvitation?>((transaction) async {
        final ref = _invitations.doc(invitationId);
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) return null;

        final data = snapshot.data()!;
        if (data['status'] != 'pending') return null;

        transaction.update(ref, {'status': 'accepted'});
        return GameInvitation.fromJson({...data, 'id': snapshot.id, 'status': 'accepted'});
      });
    } catch (e) {
      _logger.e('Failed to accept invitation: $e');
      return null;
    }
  }

  /// Decline game invitation
  Future<bool> declineInvitation({
    required String invitationId,
  }) async {
    try {
      _logger.i('Declining invitation: $invitationId');

      await _invitations.doc(invitationId).update({'status': 'declined'});

      return true;
    } catch (e) {
      _logger.e('Failed to decline invitation: $e');
      return false;
    }
  }

  /// Cancel sent invitation
  Future<bool> cancelInvitation({
    required String invitationId,
  }) async {
    try {
      _logger.i('Canceling invitation: $invitationId');

      await _invitations.doc(invitationId).delete();

      return true;
    } catch (e) {
      _logger.e('Failed to cancel invitation: $e');
      return false;
    }
  }

  /// Get incoming invitations
  Future<List<GameInvitation>> getIncomingInvitations({
    required String uid,
  }) async {
    try {
      _logger.i('Getting incoming invitations for: $uid');

      // expiresAt is stored as an ISO8601 string (see sendInvitation), so
      // the comparison operand must be the same type/format for Firestore
      // to actually match/order against it.
      final now = DateTime.now().toIso8601String();

      final querySnapshot = await _invitations
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt')
          .get();

      final invitations = querySnapshot.docs
          .map((doc) => GameInvitation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return invitations;
    } catch (e) {
      _logger.e('Failed to get incoming invitations: $e');
      return [];
    }
  }

  /// Get outgoing invitations
  Future<List<GameInvitation>> getOutgoingInvitations({
    required String uid,
  }) async {
    try {
      _logger.i('Getting outgoing invitations for: $uid');

      final now = DateTime.now().toIso8601String();

      final querySnapshot = await _invitations
          .where('fromUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt')
          .get();

      final invitations = querySnapshot.docs
          .map((doc) => GameInvitation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return invitations;
    } catch (e) {
      _logger.e('Failed to get outgoing invitations: $e');
      return [];
    }
  }

  /// Get invitation by ID
  Future<GameInvitation?> getInvitation({required String invitationId}) async {
    try {
      _logger.i('Getting invitation: $invitationId');

      final doc = await _invitations.doc(invitationId).get();

      if (!doc.exists) {
        return null;
      }

      return GameInvitation.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      _logger.e('Failed to get invitation: $e');
      return null;
    }
  }

  /// Stream incoming invitations (real-time)
  Stream<List<GameInvitation>> streamIncomingInvitations({
    required String uid,
  }) {
    final now = DateTime.now().toIso8601String();

    return _invitations
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GameInvitation.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  /// Deletes [uid]'s own expired pending invitations (sent or received).
  ///
  /// There's no admin/server context in this app to run a global sweep
  /// (and firestore.rules only allows a participant to delete their own
  /// invitation anyway), so this is scoped to one user and meant to be
  /// called opportunistically whenever that user's invitations are loaded,
  /// not on a schedule. Reads already filter out expired invitations
  /// (see getIncomingInvitations et al.), so this is housekeeping, not a
  /// correctness requirement - a failure here is harmless.
  Future<int> cleanupExpiredInvitations({required String uid}) async {
    final now = DateTime.now().toIso8601String();
    var deletedCount = 0;

    for (final field in ['fromUid', 'toUid']) {
      try {
        final querySnapshot = await _invitations
            .where(field, isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .where('expiresAt', isLessThan: now)
            .get();

        for (final doc in querySnapshot.docs) {
          try {
            await doc.reference.delete();
            deletedCount++;
          } catch (e) {
            _logger.w('Failed to delete expired invitation ${doc.id} (non-fatal): $e');
          }
        }
      } catch (e) {
        _logger.w('Failed to query expired invitations by $field (non-fatal): $e');
      }
    }

    if (deletedCount > 0) {
      _logger.i('Deleted $deletedCount expired invitations for $uid');
    }
    return deletedCount;
  }

  /// Get invitation statistics
  Future<Map<String, dynamic>> getInvitationStats({required String uid}) async {
    try {
      _logger.i('Getting invitation stats for: $uid');

      final incoming = await getIncomingInvitations(uid: uid);
      final outgoing = await getOutgoingInvitations(uid: uid);

      return {
        'incomingCount': incoming.length,
        'outgoingCount': outgoing.length,
        'incomingByMode': _groupByMode(incoming),
      };
    } catch (e) {
      _logger.e('Failed to get invitation stats: $e');
      return {};
    }
  }

  Map<String, int> _groupByMode(List<GameInvitation> invitations) {
    final grouped = <String, int>{};
    for (final invitation in invitations) {
      grouped[invitation.gameMode] = (grouped[invitation.gameMode] ?? 0) + 1;
    }
    return grouped;
  }
}

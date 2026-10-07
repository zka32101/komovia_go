import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/extended_game_models.dart';
import 'package:komovia_go/services/friend_service.dart';
import 'package:komovia_go/services/game_invitation_service.dart';

void main() {
  late FriendService friendService;
  late GameInvitationService invitationService;

  // Test user IDs
  const testUserId1 = 'test-user-1';
  const testUserId2 = 'test-user-2';
  const testUserId3 = 'test-user-3';
  const testUserId4 = 'test-user-4';

  setUpAll(() async {
    // Real FirebaseFirestore.instance has no backend to talk to under
    // flutter_test; inject a shared in-memory fake instead, seeded with
    // user docs so FriendService can denormalize displayName onto its
    // friend-relationship records.
    final firestore = FakeFirebaseFirestore();
    for (final uid in [testUserId1, testUserId2, testUserId3, testUserId4]) {
      await firestore.collection('users').doc(uid).set({
        'displayName': 'User $uid',
      });
    }
    friendService = FriendService(firestore: firestore);
    invitationService = GameInvitationService(firestore: firestore);
  });

  group('Friend System Integration Tests', () {
    test('Add friend and check friendship status', () async {
      final success = await friendService.addFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
      );

      expect(success, isTrue);
    });

    test('Accept friend request', () async {
      await friendService.addFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
      );

      final accepted = await friendService.acceptFriendRequest(
        currentUid: testUserId2,
        friendUid: testUserId1,
      );

      expect(accepted, isTrue);
    });

    test('Block user', () async {
      final blocked = await friendService.blockFriend(
        currentUid: testUserId1,
        friendUid: testUserId3,
      );

      expect(blocked, isTrue);
    });

    test('Get friends list', () async {
      // Uses a dedicated pair (not testUserId1/testUserId2) since those
      // are already 'accepted' by this point in the suite (from "Accept
      // friend request" above) - addFriend refuses to reset an existing
      // accepted/blocked relationship back to 'pending', so reusing that
      // pair here would never actually produce a pending entry to find.
      await friendService.addFriend(
        currentUid: testUserId1,
        friendUid: testUserId4,
      );

      final friends = await friendService.getFriends(
        uid: testUserId1,
        status: 'pending',
      );

      expect(friends, isNotEmpty);
    });

    test('Remove friend', () async {
      await friendService.addFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
      );

      final removed = await friendService.removeFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
      );

      expect(removed, isTrue);
    });

    test('Search users', () async {
      final users = await friendService.searchUsers(query: 'test');

      expect(users, isA<List<UserProfile>>());
    });
  });

  group('Game Invitation Integration Tests', () {
    test('Send game invitation', () async {
      final sent = await invitationService.sendInvitation(
        fromUid: testUserId1,
        fromDisplayName: 'Player 1',
        toUid: testUserId2,
        toDisplayName: 'Player 2',
        boardSize: 19,
      );

      expect(sent, isTrue);
    });

    test('Accept game invitation', () async {
      await invitationService.sendInvitation(
        fromUid: testUserId1,
        fromDisplayName: 'Player 1',
        toUid: testUserId2,
        toDisplayName: 'Player 2',
        boardSize: 19,
      );

      final incoming = await invitationService.getIncomingInvitations(
        uid: testUserId2,
      );

      if (incoming.isNotEmpty) {
        final accepted = await invitationService.acceptInvitation(
          invitationId: incoming[0].id,
        );

        expect(accepted, isNotNull);
      }
    });

    test('Decline game invitation', () async {
      await invitationService.sendInvitation(
        fromUid: testUserId1,
        fromDisplayName: 'Player 1',
        toUid: testUserId2,
        toDisplayName: 'Player 2',
        boardSize: 13,
      );

      final incoming = await invitationService.getIncomingInvitations(
        uid: testUserId2,
      );

      if (incoming.isNotEmpty) {
        final declined = await invitationService.declineInvitation(
          invitationId: incoming[0].id,
        );

        expect(declined, isTrue);
      }
    });

    test('Get incoming invitations', () async {
      final invitations =
          await invitationService.getIncomingInvitations(uid: testUserId2);

      expect(invitations, isA<List<GameInvitation>>());
    });

    test('Get outgoing invitations', () async {
      final invitations =
          await invitationService.getOutgoingInvitations(uid: testUserId1);

      expect(invitations, isA<List<GameInvitation>>());
    });

    test('Cleanup expired invitations', () async {
      final deletedCount = await invitationService.cleanupExpiredInvitations(
        uid: testUserId1,
      );

      expect(deletedCount, isA<int>());
      expect(deletedCount, greaterThanOrEqualTo(0));
    });

    test('Get invitation statistics', () async {
      final stats = await invitationService.getInvitationStats(
        uid: testUserId1,
      );

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats, containsPair('incomingCount', isA<int>()));
      expect(stats, containsPair('outgoingCount', isA<int>()));
    });
  });

  group('Social Features Integration Scenarios', () {
    test('Complete friend addition workflow', () async {
      // User 1 sends friend request to User 2
      final sent = await friendService.addFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
        notes: 'Great player!',
      );
      expect(sent, isTrue);

      // User 2 accepts the request
      final accepted = await friendService.acceptFriendRequest(
        currentUid: testUserId2,
        friendUid: testUserId1,
      );
      expect(accepted, isTrue);

      // Verify friendship
      final isFriend = await friendService.isFriend(
        currentUid: testUserId1,
        friendUid: testUserId2,
      );
      expect(isFriend, isTrue);
    });

    test('Complete game invitation workflow', () async {
      // User 1 sends game invitation to User 2
      final sent = await invitationService.sendInvitation(
        fromUid: testUserId1,
        fromDisplayName: 'Player 1',
        toUid: testUserId2,
        toDisplayName: 'Player 2',
        boardSize: 19,
        customMessage: 'Want to play?',
      );
      expect(sent, isTrue);

      // Get User 2's incoming invitations
      final incoming = await invitationService.getIncomingInvitations(
        uid: testUserId2,
      );
      expect(incoming, isNotEmpty);

      // User 2 accepts the invitation
      if (incoming.isNotEmpty) {
        final accepted = await invitationService.acceptInvitation(
          invitationId: incoming[0].id,
        );
        expect(accepted, isNotNull);
      }
    });

  });
}

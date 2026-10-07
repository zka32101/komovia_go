import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/game_invitation_service.dart';

void main() {
  group('GameInvitationService', () {
    late FakeFirebaseFirestore firestore;
    late GameInvitationService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = GameInvitationService(firestore: firestore);
    });

    test('sendInvitation stores board size and both display names', () async {
      final sent = await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 13,
      );
      expect(sent, isTrue);

      final incoming = await service.getIncomingInvitations(uid: 'uid2');
      expect(incoming, hasLength(1));
      expect(incoming.first.boardSize, 13);
      expect(incoming.first.fromDisplayName, 'Alice');
      expect(incoming.first.toDisplayName, 'Bob');
      expect(incoming.first.status, 'pending');
    });

    test('sendInvitation refuses when the sender or recipient has a blocked relationship',
        () async {
      await firestore
          .collection('users')
          .doc('uid1')
          .collection('friends')
          .doc('uid2')
          .set({'status': 'blocked'});

      final sent = await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 9,
      );

      expect(sent, isFalse);
      expect(await service.getIncomingInvitations(uid: 'uid2'), isEmpty);
    });

    test('getIncomingInvitations only returns invitations for that recipient', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid3',
        toDisplayName: 'Carol',
        boardSize: 9,
      );

      final forBob = await service.getIncomingInvitations(uid: 'uid2');
      expect(forBob, hasLength(1));
      expect(forBob.first.toUid, 'uid2');
    });

    test('acceptInvitation flips status to accepted and returns the invitation', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      final invitation = (await service.getIncomingInvitations(uid: 'uid2')).single;

      final accepted = await service.acceptInvitation(invitationId: invitation.id);

      expect(accepted, isNotNull);
      expect(accepted!.status, 'accepted');
      expect(accepted.boardSize, 19);

      // No longer shows up as a pending incoming invitation.
      final stillIncoming = await service.getIncomingInvitations(uid: 'uid2');
      expect(stillIncoming, isEmpty);
    });

    test('acceptInvitation returns null on a second, redundant accept (no double game '
        'creation from a double-tap)', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      final invitation = (await service.getIncomingInvitations(uid: 'uid2')).single;

      final first = await service.acceptInvitation(invitationId: invitation.id);
      final second = await service.acceptInvitation(invitationId: invitation.id);

      expect(first, isNotNull);
      expect(second, isNull);
    });

    test('acceptInvitation returns null for a nonexistent invitation', () async {
      final accepted = await service.acceptInvitation(invitationId: 'does-not-exist');
      expect(accepted, isNull);
    });

    test('declineInvitation flips status to declined', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      final invitation = (await service.getIncomingInvitations(uid: 'uid2')).single;

      final declined = await service.declineInvitation(invitationId: invitation.id);
      expect(declined, isTrue);

      final doc = await firestore.collection('gameInvitations').doc(invitation.id).get();
      expect(doc.data()!['status'], 'declined');

      final stillIncoming = await service.getIncomingInvitations(uid: 'uid2');
      expect(stillIncoming, isEmpty);
    });

    test('cancelInvitation deletes the invitation outright', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      final invitation = (await service.getOutgoingInvitations(uid: 'uid1')).single;

      final cancelled = await service.cancelInvitation(invitationId: invitation.id);
      expect(cancelled, isTrue);

      final doc = await firestore.collection('gameInvitations').doc(invitation.id).get();
      expect(doc.exists, isFalse);
    });

    group('cleanupExpiredInvitations', () {
      Future<String> seedInvitation({
        required String fromUid,
        required String toUid,
        required DateTime expiresAt,
        String status = 'pending',
      }) async {
        final ref = firestore.collection('gameInvitations').doc();
        await ref.set({
          'id': ref.id,
          'fromUid': fromUid,
          'fromDisplayName': 'From',
          'toUid': toUid,
          'toDisplayName': 'To',
          'gameMode': 'standard',
          'boardSize': 19,
          'createdAt': DateTime.now().toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'status': status,
          'customMessage': '',
        });
        return ref.id;
      }

      test('deletes the calling user\'s own expired pending invitations, sent or received',
          () async {
        final sentExpired = await seedInvitation(
          fromUid: 'uid1',
          toUid: 'uid2',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        final receivedExpired = await seedInvitation(
          fromUid: 'uid3',
          toUid: 'uid1',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        final deletedCount = await service.cleanupExpiredInvitations(uid: 'uid1');

        expect(deletedCount, 2);
        expect(
          (await firestore.collection('gameInvitations').doc(sentExpired).get()).exists,
          isFalse,
        );
        expect(
          (await firestore.collection('gameInvitations').doc(receivedExpired).get()).exists,
          isFalse,
        );
      });

      test('does not touch another user\'s expired invitations', () async {
        final otherUsersExpired = await seedInvitation(
          fromUid: 'uid2',
          toUid: 'uid3',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        final deletedCount = await service.cleanupExpiredInvitations(uid: 'uid1');

        expect(deletedCount, 0);
        expect(
          (await firestore.collection('gameInvitations').doc(otherUsersExpired).get()).exists,
          isTrue,
        );
      });

      test('does not touch a not-yet-expired invitation', () async {
        final notExpired = await seedInvitation(
          fromUid: 'uid1',
          toUid: 'uid2',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        );

        final deletedCount = await service.cleanupExpiredInvitations(uid: 'uid1');

        expect(deletedCount, 0);
        expect(
          (await firestore.collection('gameInvitations').doc(notExpired).get()).exists,
          isTrue,
        );
      });

      test('does not touch an expired invitation that was already accepted', () async {
        final acceptedButExpired = await seedInvitation(
          fromUid: 'uid1',
          toUid: 'uid2',
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
          status: 'accepted',
        );

        final deletedCount = await service.cleanupExpiredInvitations(uid: 'uid1');

        expect(deletedCount, 0);
        expect(
          (await firestore.collection('gameInvitations').doc(acceptedButExpired).get()).exists,
          isTrue,
        );
      });
    });

    test('getInvitationStats reports incoming/outgoing counts', () async {
      await service.sendInvitation(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        boardSize: 19,
      );
      await service.sendInvitation(
        fromUid: 'uid3',
        fromDisplayName: 'Carol',
        toUid: 'uid1',
        toDisplayName: 'Alice',
        boardSize: 9,
      );

      final stats = await service.getInvitationStats(uid: 'uid1');
      expect(stats['outgoingCount'], 1);
      expect(stats['incomingCount'], 1);
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/friend_service.dart';

void main() {
  group('FriendService', () {
    late FakeFirebaseFirestore firestore;
    late FriendService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = FriendService(firestore: firestore);
      await firestore.collection('users').doc('me').set({'displayName': 'Me'});
      await firestore.collection('users').doc('friend').set({'displayName': 'Friend'});
    });

    test('addFriend creates a pending relationship on both sides when none exists', () async {
      final success = await service.addFriend(currentUid: 'me', friendUid: 'friend');
      expect(success, true);

      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'pending');
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), 'pending');
    });

    test('addFriend is a harmless no-op when already pending', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      final success = await service.addFriend(currentUid: 'me', friendUid: 'friend');

      expect(success, true);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'pending');
    });

    test('addFriend refuses and does not touch an already-accepted friendship', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'accepted');

      final success = await service.addFriend(currentUid: 'me', friendUid: 'friend');

      expect(success, false);
      // The whole point of this test: re-adding an accepted friend must
      // not silently reset the relationship back to 'pending'.
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'accepted');
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), 'accepted');
    });

    test('addFriend refuses and does not touch a blocked relationship', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.blockFriend(currentUid: 'me', friendUid: 'friend');
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'blocked');

      final success = await service.addFriend(currentUid: 'me', friendUid: 'friend');

      expect(success, false);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'blocked');
    });

    test('getFriendStatus returns null when no relationship exists yet', () async {
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), isNull);
    });

    test('isFriend is only true once the relationship is accepted', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      expect(await service.isFriend(currentUid: 'me', friendUid: 'friend'), false);

      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');
      expect(await service.isFriend(currentUid: 'me', friendUid: 'friend'), true);
    });

    test('addFriend records who sent the request on both sides', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');

      final mine = await service.getFriends(uid: 'me', status: 'pending');
      final theirs = await service.getFriends(uid: 'friend', status: 'pending');
      expect(mine.single.requestedBy, 'me');
      expect(theirs.single.requestedBy, 'me');
    });

    test('addFriend resending an already-pending request keeps the original sender', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      // The recipient's side calls addFriend too (e.g. search still shows
      // "追加" for a pending request) - the original sender must not flip.
      await service.addFriend(currentUid: 'friend', friendUid: 'me');

      final mine = await service.getFriends(uid: 'me', status: 'pending');
      expect(mine.single.requestedBy, 'me');
    });

    test('rejectFriendRequest removes the pending relationship on both sides', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');

      final success = await service.rejectFriendRequest(currentUid: 'friend', friendUid: 'me');

      expect(success, true);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), isNull);
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), isNull);
    });

    test('rejectFriendRequest is a no-op on an accepted friendship', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'friend', friendUid: 'me');

      final success = await service.rejectFriendRequest(currentUid: 'friend', friendUid: 'me');

      expect(success, false);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'accepted');
    });

    test('after rejecting, the same two users can send a fresh request later', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.rejectFriendRequest(currentUid: 'friend', friendUid: 'me');

      final success = await service.addFriend(currentUid: 'friend', friendUid: 'me');

      expect(success, true);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'pending');
    });

    test('unblockFriend on a block with no prior relationship just clears it', () async {
      await service.blockFriend(currentUid: 'me', friendUid: 'stranger');

      final success = await service.unblockFriend(currentUid: 'me', friendUid: 'stranger');

      expect(success, true);
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'stranger'), isNull);
    });

    test('blockFriend mirrors the block onto the target\'s own entry too', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');

      await service.blockFriend(currentUid: 'me', friendUid: 'friend');

      // Both sides now read 'blocked' - the target no longer sees the
      // blocker as an accepted friend, and can detect the block from
      // their own (readable) side.
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'blocked');
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), 'blocked');
    });

    test('blockFriend never overwrites a block the target placed independently', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');
      // The target blocks first, on their own.
      await service.blockFriend(currentUid: 'friend', friendUid: 'me');

      // Now the original party also blocks.
      await service.blockFriend(currentUid: 'me', friendUid: 'friend');

      // 'me' unblocking later must not silently lift 'friend's own block.
      await service.unblockFriend(currentUid: 'me', friendUid: 'friend');
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), 'blocked');
    });

    test('unblockFriend removes the mirror it placed on the target\'s side', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');
      await service.blockFriend(currentUid: 'me', friendUid: 'friend');

      await service.unblockFriend(currentUid: 'me', friendUid: 'friend');

      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), isNull);
      expect(await service.getFriendStatus(currentUid: 'friend', friendUid: 'me'), isNull);
    });

    test('a blocked former friend no longer appears in either side\'s accepted list', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend');
      await service.acceptFriendRequest(currentUid: 'me', friendUid: 'friend');
      await service.blockFriend(currentUid: 'me', friendUid: 'friend');

      expect(await service.getFriends(uid: 'me', status: 'accepted'), isEmpty);
      expect(await service.getFriends(uid: 'friend', status: 'accepted'), isEmpty);
    });

    test('addFriend persists notes on the caller\'s own entry only', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend', notes: 'met at a tournament');

      final mine = await firestore.collection('users').doc('me').collection('friends').doc('friend').get();
      expect(mine.data()?['notes'], 'met at a tournament');

      // Friendship.fromJson has no notes field, but this is an extra raw
      // field on the Firestore doc itself - not part of the model's JSON
      // shape - so it round-trips through the service's own read methods
      // transparently without a cast error.
      expect(await service.getFriendStatus(currentUid: 'me', friendUid: 'friend'), 'pending');

      // Never written to the other side - it's a private note, not a
      // shared relationship field.
      final theirs = await firestore.collection('users').doc('friend').collection('friends').doc('me').get();
      expect(theirs.data()?['notes'], isNull);
    });

    test('blockFriend preserves a pre-existing note when upserting the blocked entry', () async {
      await service.addFriend(currentUid: 'me', friendUid: 'friend', notes: 'old roommate');
      await service.blockFriend(currentUid: 'me', friendUid: 'friend');

      final mine = await firestore.collection('users').doc('me').collection('friends').doc('friend').get();
      expect(mine.data()?['notes'], 'old roommate');
      expect(mine.data()?['status'], 'blocked');
    });
  });
}

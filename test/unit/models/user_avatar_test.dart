import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/user.dart';

void main() {
  User buildUser({String? avatarId}) => User(
        uid: 'uid-1',
        email: 'player@example.com',
        subscriptionActive: false,
        subscriptionStartDate: DateTime(2026, 1, 1),
        tutorialCompleted: true,
        gamesPlayedCount: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        avatarId: avatarId,
      );

  group('User.avatarId', () {
    test('defaults to null when not specified', () {
      expect(buildUser().avatarId, isNull);
    });

    test('resolves to the shared default avatar when null', () {
      expect(avatarIconById(buildUser().avatarId).id, equals('fox'));
    });

    test('resolves to the chosen avatar when set', () {
      expect(avatarIconById(buildUser(avatarId: 'owl').avatarId).id, equals('owl'));
    });

    test('an unknown/stale avatarId still falls back to the default', () {
      expect(
        avatarIconById(buildUser(avatarId: 'no-such-id').avatarId).id,
        equals('fox'),
      );
    });

    test('copyWith overrides avatarId', () {
      final updated = buildUser(avatarId: 'fox').copyWith(avatarId: 'tiger');
      expect(updated.avatarId, equals('tiger'));
    });

    test('copyWith without avatarId preserves the existing value', () {
      final updated = buildUser(avatarId: 'tiger').copyWith(displayName: 'New Name');
      expect(updated.avatarId, equals('tiger'));
    });

    test('round-trips through Firestore (toFirestore/fromFirestore)', () async {
      final firestore = FakeFirebaseFirestore();
      final user = buildUser(avatarId: 'panda');
      await firestore.collection('users').doc(user.uid).set(user.toFirestore());

      final doc = await firestore.collection('users').doc(user.uid).get();
      final roundTripped = User.fromFirestore(doc);

      expect(roundTripped.avatarId, equals('panda'));
    });

    test(
      'a pre-existing document written before this field existed has no '
      'avatarId key at all, and still parses with avatarId null',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('users').doc('legacy-uid').set({
          'email': 'old@example.com',
          'subscriptionActive': false,
          'tutorialCompleted': true,
          'gamesPlayedCount': 3,
          // No 'avatarId' key at all - simulates a document written
          // before this feature existed.
        });

        final doc = await firestore.collection('users').doc('legacy-uid').get();
        final user = User.fromFirestore(doc);

        expect(user.avatarId, isNull);
        expect(avatarIconById(user.avatarId).id, equals('fox'));
      },
    );
  });
}

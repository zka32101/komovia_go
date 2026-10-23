import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/utils/entitlement_adapter.dart';

User _user({
  required bool subscriptionActive,
  DateTime? subscriptionEndDate,
}) {
  final now = DateTime(2026, 1, 1);
  return User(
    uid: 'u1',
    email: 'u1@example.com',
    subscriptionActive: subscriptionActive,
    subscriptionStartDate: now,
    subscriptionEndDate: subscriptionEndDate,
    tutorialCompleted: true,
    gamesPlayedCount: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('UserEntitlement.toEntitlement', () {
    test('maps active, non-expiring subscription', () {
      final entitlement = _user(subscriptionActive: true).toEntitlement();
      expect(entitlement.isActive, isTrue);
      expect(entitlement.expiresAt, isNull);
      expect(entitlement.isCurrentlyActive(now: DateTime(2099)), isTrue);
    });

    test('isCurrentlyActive re-derives from an expired end date', () {
      final past = DateTime(2020, 1, 1);
      final entitlement =
          _user(subscriptionActive: true, subscriptionEndDate: past)
              .toEntitlement();
      // The stored flag still says true, but the real expiry has passed.
      expect(entitlement.isActive, isTrue);
      expect(
        entitlement.isCurrentlyActive(now: DateTime(2026, 6, 1)),
        isFalse,
      );
    });

    test('an active, not-yet-expired subscription stays active', () {
      final future = DateTime(2099, 1, 1);
      final entitlement =
          _user(subscriptionActive: true, subscriptionEndDate: future)
              .toEntitlement();
      expect(
        entitlement.isCurrentlyActive(now: DateTime(2026, 6, 1)),
        isTrue,
      );
    });

    test('never-subscribed user maps to an inactive entitlement', () {
      final entitlement = _user(subscriptionActive: false).toEntitlement();
      expect(entitlement.isCurrentlyActive(), isFalse);
    });
  });
}

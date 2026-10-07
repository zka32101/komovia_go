import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// Deletes the Firestore data owned by a user when they delete their account.
///
/// Best effort: every step is attempted independently so one rule rejection
/// or network error never leaves the rest of the user's data behind, and the
/// whole operation is idempotent (safe to retry). The steps that failed are
/// returned so callers can log them.
///
/// Data shared with other players (direct messages, PvP game records,
/// tournaments) is intentionally not touched here; the account deletion page
/// tells users to email us to have those removed.
class AccountDataDeletionService {
  AccountDataDeletionService({FirebaseFirestore? firestore, Logger? logger})
      : _db = firestore ?? FirebaseFirestore.instance,
        _logger = logger ?? Logger();

  final FirebaseFirestore _db;
  final Logger _logger;

  /// Subcollections under `users/{uid}`.
  static const userSubcollections = [
    'friends',
    'gameRecords',
    'stats',
    'achievements',
    'gamePresets',
    'oauth',
    'sponsorshipTiers',
    'sponsorshipNotifications',
  ];

  /// Top-level collections whose documents carry a `uid` field.
  static const uidFieldCollections = [
    'gameRecords',
    'userTsumeGoLogs',
    'observationLogs',
  ];

  /// Subcollections of `notifications/{uid}`.
  static const notificationSubcollections = [
    'messages',
    'fcmTokens',
    'notificationPreferences',
  ];

  /// Documents keyed by the user's uid.
  static const uidKeyedCollections = [
    'leaderboard_global',
    'active_play_sessions',
    'playstyle_profiles',
  ];

  /// Returns the names of the steps that failed (empty when all succeeded).
  Future<List<String>> deleteAllUserData(String uid) async {
    final failures = <String>[];

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (e) {
        _logger.w('Account data deletion step "$name" failed: $e');
        failures.add(name);
      }
    }

    // Remove the mirror of this user inside each friend's list first, while
    // our own friends list still tells us who they are.
    await step('friend mirrors', () async {
      final friends = await _db.collection('users').doc(uid).collection('friends').get();
      for (final doc in friends.docs) {
        await _db.collection('users').doc(doc.id).collection('friends').doc(uid).delete();
      }
    });

    for (final sub in userSubcollections) {
      await step('users/$uid/$sub', () => _deleteCollection(_db.collection('users').doc(uid).collection(sub)));
    }

    for (final name in uidFieldCollections) {
      await step(name, () async {
        final snap = await _db.collection(name).where('uid', isEqualTo: uid).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      });
    }

    for (final sub in notificationSubcollections) {
      await step('notifications/$uid/$sub',
          () => _deleteCollection(_db.collection('notifications').doc(uid).collection(sub)));
    }

    await step('user_analytics/$uid/social',
        () => _deleteCollection(_db.collection('user_analytics').doc(uid).collection('social')));
    await step('en_scores/$uid/connections',
        () => _deleteCollection(_db.collection('en_scores').doc(uid).collection('connections')));

    for (final name in uidKeyedCollections) {
      await step('$name/$uid', () => _db.collection(name).doc(uid).delete());
    }

    // The profile document last: if an earlier step is retried after a
    // failure, the account is still identifiable.
    await step('users/$uid', () => _db.collection('users').doc(uid).delete());

    return failures;
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sentinel for User.copyWith's subscriptionEndDate parameter, to
/// distinguish "not passed" from "explicitly passed null".
const Object _unset = Object();

/// User profile and subscription status
class User {
  final String uid;
  final String email;
  final String? displayName;
  final bool subscriptionActive;
  final DateTime subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool tutorialCompleted;
  final int gamesPlayedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    required this.subscriptionActive,
    required this.subscriptionStartDate,
    this.subscriptionEndDate,
    required this.tutorialCompleted,
    required this.gamesPlayedCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory User.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return User(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      subscriptionActive: data['subscriptionActive'] ?? false,
      subscriptionStartDate: data['subscriptionStartDate'] is Timestamp
          ? (data['subscriptionStartDate'] as Timestamp).toDate()
          : DateTime.now(),
      subscriptionEndDate: data['subscriptionEndDate'] is Timestamp
          ? (data['subscriptionEndDate'] as Timestamp).toDate()
          : null,
      tutorialCompleted: data['tutorialCompleted'] ?? false,
      gamesPlayedCount: data['gamesPlayedCount'] ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'subscriptionActive': subscriptionActive,
      'subscriptionStartDate': Timestamp.fromDate(subscriptionStartDate),
      'subscriptionEndDate': subscriptionEndDate != null
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
      'tutorialCompleted': tutorialCompleted,
      'gamesPlayedCount': gamesPlayedCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy with modifications.
  ///
  /// subscriptionEndDate uses a sentinel default rather than `Type? field`
  /// so it can be explicitly cleared to null (e.g. a lifetime purchase that
  /// never expires) - `field ?? this.field` can never distinguish "not
  /// passed" from "explicitly passed null".
  User copyWith({
    String? email,
    String? displayName,
    bool? subscriptionActive,
    DateTime? subscriptionStartDate,
    Object? subscriptionEndDate = _unset,
    bool? tutorialCompleted,
    int? gamesPlayedCount,
    DateTime? updatedAt,
  }) {
    return User(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: identical(subscriptionEndDate, _unset)
          ? this.subscriptionEndDate
          : subscriptionEndDate as DateTime?,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      gamesPlayedCount: gamesPlayedCount ?? this.gamesPlayedCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'User(uid: $uid, email: $email, subscriptionActive: $subscriptionActive, tutorialCompleted: $tutorialCompleted)';
}

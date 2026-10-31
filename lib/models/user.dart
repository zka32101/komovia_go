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

  /// Preset avatar id from komovia_core's `kAvatarIcons` catalog (e.g.
  /// 'fox'), or null for every user who hasn't picked one yet (including
  /// everyone who existed before this field was added). Never resolve this
  /// directly — always go through `avatarIconById(user.avatarId)`, which
  /// safely falls back to the shared default for null/unknown ids.
  final String? avatarId;

  /// Selected cosmetic skins (see `go_skins.dart`); null = default. Always
  /// resolve through `boardSkinById`/`stoneSkinById`, which fall back safely.
  final String? boardSkinId;
  final String? stoneSkinId;

  /// Store product ids of one-time cosmetic purchases this user owns.
  final List<String> purchasedCosmeticIds;

  /// Selected avatar frame id from `lib/config/avatar_frames.dart`'s
  /// catalog, or null for no frame. Frames are earned, never purchased;
  /// always resolve via `resolveDisplayedFrame` so a frame that's no
  /// longer unlocked (e.g. a rank-based frame after losing that rank)
  /// silently stops rendering instead of trusting this stored value.
  final String? frameId;

  /// "Sticky" frame unlocks for point-in-time achievements that can't be
  /// re-derived live from currently tracked stats (a tsume-go streak that
  /// has since broken, a past max En score). Frames derivable live from
  /// monotonic/current stats are NOT stored here.
  final List<String> earnedFrameIds;

  /// AI分析プラン(別売りの月額商品)の有効期限。null = 未加入。
  /// 既存プレミアムの subscriptionActive/EndDate とは独立している。
  final DateTime? aiAnalysisPlanEndDate;

  /// AI分析プランが [now] 時点で有効か。
  bool hasAiAnalysisPlan(DateTime now) =>
      aiAnalysisPlanEndDate != null && aiAnalysisPlanEndDate!.isAfter(now);

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
    this.avatarId,
    this.boardSkinId,
    this.stoneSkinId,
    this.purchasedCosmeticIds = const [],
    this.frameId,
    this.earnedFrameIds = const [],
    this.aiAnalysisPlanEndDate,
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
      avatarId: data['avatarId'],
      boardSkinId: data['boardSkinId'] as String?,
      stoneSkinId: data['stoneSkinId'] as String?,
      purchasedCosmeticIds: (data['purchasedCosmeticIds'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      frameId: data['frameId'] as String?,
      earnedFrameIds:
          (data['earnedFrameIds'] as List?)?.whereType<String>().toList() ??
              const [],
      aiAnalysisPlanEndDate: data['aiAnalysisPlanEndDate'] is Timestamp
          ? (data['aiAnalysisPlanEndDate'] as Timestamp).toDate()
          : null,
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
      'avatarId': avatarId,
      'boardSkinId': boardSkinId,
      'stoneSkinId': stoneSkinId,
      'purchasedCosmeticIds': purchasedCosmeticIds,
      'frameId': frameId,
      'earnedFrameIds': earnedFrameIds,
      'aiAnalysisPlanEndDate': aiAnalysisPlanEndDate != null
          ? Timestamp.fromDate(aiAnalysisPlanEndDate!)
          : null,
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
    String? avatarId,
    String? boardSkinId,
    String? stoneSkinId,
    List<String>? purchasedCosmeticIds,
    Object? frameId = _unset,
    List<String>? earnedFrameIds,
    Object? aiAnalysisPlanEndDate = _unset,
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
      avatarId: avatarId ?? this.avatarId,
      boardSkinId: boardSkinId ?? this.boardSkinId,
      stoneSkinId: stoneSkinId ?? this.stoneSkinId,
      purchasedCosmeticIds: purchasedCosmeticIds ?? this.purchasedCosmeticIds,
      frameId: identical(frameId, _unset) ? this.frameId : frameId as String?,
      earnedFrameIds: earnedFrameIds ?? this.earnedFrameIds,
      aiAnalysisPlanEndDate: identical(aiAnalysisPlanEndDate, _unset)
          ? this.aiAnalysisPlanEndDate
          : aiAnalysisPlanEndDate as DateTime?,
    );
  }

  @override
  String toString() =>
      'User(uid: $uid, email: $email, subscriptionActive: $subscriptionActive, tutorialCompleted: $tutorialCompleted)';
}

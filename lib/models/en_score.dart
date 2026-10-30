import 'package:cloud_firestore/cloud_firestore.dart';

/// 「縁」スコア - 2人のユーザー間のつながりの深さを可視化する
class EnConnection {
  final String uid;
  final String friendUid;
  final String friendDisplayName;
  final int score; // 0〜100、高いほど「縁」が深い
  final int friendshipDays;
  final int matchesPlayed;
  final int sharedSpectateSessions;
  final int sharedPositionEchoes;
  final DateTime calculatedAt;

  EnConnection({
    required this.uid,
    required this.friendUid,
    required this.friendDisplayName,
    required this.score,
    required this.friendshipDays,
    required this.matchesPlayed,
    required this.sharedSpectateSessions,
    required this.sharedPositionEchoes,
    required this.calculatedAt,
  });

  /// ログなど画面外で使う日本語の呼び名。画面では [levelLabel] を使う。
  String get level => levelLabel(ja: true);

  String levelLabel({required bool ja}) {
    if (score >= 80) return ja ? '深い縁' : 'Deep bond';
    if (score >= 50) return ja ? '育ちゆく縁' : 'Growing bond';
    if (score >= 20) return ja ? '芽生えた縁' : 'Budding bond';
    return ja ? '出会ったばかりの縁' : 'Newly met';
  }

  factory EnConnection.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EnConnection(
      uid: data['uid'] as String? ?? '',
      friendUid: doc.id,
      friendDisplayName: data['friendDisplayName'] as String? ?? 'Friend',
      score: data['score'] as int? ?? 0,
      friendshipDays: data['friendshipDays'] as int? ?? 0,
      matchesPlayed: data['matchesPlayed'] as int? ?? 0,
      sharedSpectateSessions: data['sharedSpectateSessions'] as int? ?? 0,
      sharedPositionEchoes: data['sharedPositionEchoes'] as int? ?? 0,
      calculatedAt: data['calculatedAt'] != null
          ? (data['calculatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'friendDisplayName': friendDisplayName,
      'score': score,
      'friendshipDays': friendshipDays,
      'matchesPlayed': matchesPlayed,
      'sharedSpectateSessions': sharedSpectateSessions,
      'sharedPositionEchoes': sharedPositionEchoes,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// 局面の轍 - あるユーザーが到達した局面の記録（歴史的名局と同じ局面に辿り着いた「縁」を検出する）
class PositionEcho {
  final String id;
  final String positionHash;
  final String uid;
  final String displayName;
  final String? kifuId; // 一致した歴史的名局のID（あれば）
  final String? kifuTitle;
  final int moveNumber;
  final int boardSize;
  final DateTime reachedAt;

  PositionEcho({
    required this.id,
    required this.positionHash,
    required this.uid,
    required this.displayName,
    this.kifuId,
    this.kifuTitle,
    required this.moveNumber,
    required this.boardSize,
    required this.reachedAt,
  });

  factory PositionEcho.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PositionEcho(
      id: doc.id,
      positionHash: data['positionHash'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Player',
      kifuId: data['kifuId'] as String?,
      kifuTitle: data['kifuTitle'] as String?,
      moveNumber: data['moveNumber'] as int? ?? 0,
      boardSize: data['boardSize'] as int? ?? 19,
      reachedAt: data['reachedAt'] != null
          ? (data['reachedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'positionHash': positionHash,
      'uid': uid,
      'displayName': displayName,
      'kifuId': kifuId,
      'kifuTitle': kifuTitle,
      'moveNumber': moveNumber,
      'boardSize': boardSize,
      'reachedAt': Timestamp.fromDate(reachedAt),
    };
  }

  bool get matchesHistoricalGame => kifuId != null;
}

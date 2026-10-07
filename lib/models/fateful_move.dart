import 'package:cloud_firestore/cloud_firestore.dart';

/// 運命の一手 - AIが検出した「美しい/劇的な」一手の記録
class FatefulMove {
  final String id;
  final String uid;
  final String displayName;
  final String? gameId;
  final int moveNumber;
  final int boardSize;
  final FatefulMoveType type;
  final int stonesCaptured;
  final DateTime detectedAt;
  final bool sharedWithFriends;

  FatefulMove({
    required this.id,
    required this.uid,
    required this.displayName,
    this.gameId,
    required this.moveNumber,
    required this.boardSize,
    required this.type,
    required this.stonesCaptured,
    required this.detectedAt,
    required this.sharedWithFriends,
  });

  factory FatefulMove.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return FatefulMove(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Player',
      gameId: data['gameId'] as String?,
      moveNumber: data['moveNumber'] as int? ?? 0,
      boardSize: data['boardSize'] as int? ?? 19,
      type: FatefulMoveType.fromString(data['type'] as String? ?? 'tesuji'),
      stonesCaptured: data['stonesCaptured'] as int? ?? 0,
      detectedAt: data['detectedAt'] != null
          ? (data['detectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      sharedWithFriends: data['sharedWithFriends'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'gameId': gameId,
      'moveNumber': moveNumber,
      'boardSize': boardSize,
      'type': type.toShortString(),
      'stonesCaptured': stonesCaptured,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'sharedWithFriends': sharedWithFriends,
    };
  }
}

/// 運命の一手の種類
enum FatefulMoveType {
  bigCapture, // 大石を仕留めた
  tesuji, // 際どい戦術的妙手
  koFight, // 劫争いの決着
  lifeAndDeath; // 死活の決着

  String toShortString() {
    switch (this) {
      case FatefulMoveType.bigCapture:
        return 'big_capture';
      case FatefulMoveType.tesuji:
        return 'tesuji';
      case FatefulMoveType.koFight:
        return 'ko_fight';
      case FatefulMoveType.lifeAndDeath:
        return 'life_and_death';
    }
  }

  static FatefulMoveType fromString(String value) {
    switch (value) {
      case 'big_capture':
        return FatefulMoveType.bigCapture;
      case 'ko_fight':
        return FatefulMoveType.koFight;
      case 'life_and_death':
        return FatefulMoveType.lifeAndDeath;
      default:
        return FatefulMoveType.tesuji;
    }
  }

  String getDisplayName() {
    switch (this) {
      case FatefulMoveType.bigCapture:
        return '大石を仕留めた一手';
      case FatefulMoveType.tesuji:
        return '妙手';
      case FatefulMoveType.koFight:
        return '劫の決め手';
      case FatefulMoveType.lifeAndDeath:
        return '死活を決めた一手';
    }
  }
}

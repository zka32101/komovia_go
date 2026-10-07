import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a completed game against AI
class GameRecord {
  final String id;
  final String uid;
  final int boardSize; // 9, 13, or 19
  final String sgfData; // Standard Game Format (SGF) data
  final GameResult result;
  final int aiLevel; // 1-10 difficulty level
  final DateTime playedAt;
  final int? movesCount;
  final Duration? gameDuration;
  final double? blackScore; // Score for black player (Chinese rules)
  final double? whiteScore; // Score for white player (Chinese rules)

  GameRecord({
    required this.id,
    required this.uid,
    required this.boardSize,
    required this.sgfData,
    required this.result,
    required this.aiLevel,
    required this.playedAt,
    this.movesCount,
    this.gameDuration,
    this.blackScore,
    this.whiteScore,
  });

  /// Create from Firestore document
  factory GameRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GameRecord(
      id: doc.id,
      uid: data['uid'] ?? '',
      boardSize: data['boardSize'] ?? 19,
      sgfData: data['sgfData'] ?? '',
      result: GameResult.fromString(data['result'] ?? 'draw'),
      aiLevel: data['aiLevel'] ?? 1,
      playedAt: data['playedAt'] is Timestamp
          ? (data['playedAt'] as Timestamp).toDate()
          : DateTime.now(),
      movesCount: data['movesCount'],
      gameDuration: data['gameDuration'] != null
          ? Duration(seconds: data['gameDuration'] as int)
          : null,
      blackScore: (data['blackScore'] as num?)?.toDouble(),
      whiteScore: (data['whiteScore'] as num?)?.toDouble(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'boardSize': boardSize,
      'sgfData': sgfData,
      'result': result.toShortString(),
      'aiLevel': aiLevel,
      'playedAt': Timestamp.fromDate(playedAt),
      'movesCount': movesCount,
      'gameDuration': gameDuration?.inSeconds,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
    };
  }

  @override
  String toString() =>
      'GameRecord(id: $id, uid: $uid, boardSize: $boardSize, result: $result, aiLevel: $aiLevel)';
}

/// Game result enum
enum GameResult {
  playerWin,
  aiWin,
  draw,
  resignation,
  unknown;

  String toShortString() {
    switch (this) {
      case GameResult.playerWin:
        return 'player_win';
      case GameResult.aiWin:
        return 'ai_win';
      case GameResult.draw:
        return 'draw';
      case GameResult.resignation:
        return 'resignation';
      case GameResult.unknown:
        return 'unknown';
    }
  }

  static GameResult fromString(String value) {
    switch (value) {
      case 'player_win':
        return GameResult.playerWin;
      case 'ai_win':
        return GameResult.aiWin;
      case 'draw':
        return GameResult.draw;
      case 'resignation':
        return GameResult.resignation;
      default:
        return GameResult.unknown;
    }
  }

  @override
  String toString() => toShortString();
}

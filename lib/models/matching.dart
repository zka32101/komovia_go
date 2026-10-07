import 'package:cloud_firestore/cloud_firestore.dart';

/// マッチメイキング待機列のエントリ（「運命の対戦」を待つプレイヤー）
class MatchmakingQueueEntry {
  final String uid;
  final String displayName;
  final int rating;
  final int boardSize;
  final DateTime queuedAt;
  final String status; // 'waiting', 'matched', 'cancelled'

  MatchmakingQueueEntry({
    required this.uid,
    required this.displayName,
    required this.rating,
    required this.boardSize,
    required this.queuedAt,
    required this.status,
  });

  factory MatchmakingQueueEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return MatchmakingQueueEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Player',
      rating: data['rating'] as int? ?? 1200,
      boardSize: data['boardSize'] as int? ?? 19,
      queuedAt: data['queuedAt'] != null
          ? (data['queuedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'waiting',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'rating': rating,
      'boardSize': boardSize,
      'queuedAt': Timestamp.fromDate(queuedAt),
      'status': status,
    };
  }
}

/// 成立したマッチ（「運命の対戦」）
class MatchResult {
  final String id;
  final String player1Uid;
  final String player1DisplayName;
  final int player1Rating;
  final String player2Uid;
  final String player2DisplayName;
  final int player2Rating;
  final int boardSize;
  final int ratingDiff;
  final DateTime createdAt;
  final String? gameId;

  MatchResult({
    required this.id,
    required this.player1Uid,
    required this.player1DisplayName,
    required this.player1Rating,
    required this.player2Uid,
    required this.player2DisplayName,
    required this.player2Rating,
    required this.boardSize,
    required this.ratingDiff,
    required this.createdAt,
    this.gameId,
  });

  factory MatchResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return MatchResult(
      id: doc.id,
      player1Uid: data['player1Uid'] as String? ?? '',
      player1DisplayName: data['player1DisplayName'] as String? ?? 'Player',
      player1Rating: data['player1Rating'] as int? ?? 1200,
      player2Uid: data['player2Uid'] as String? ?? '',
      player2DisplayName: data['player2DisplayName'] as String? ?? 'Player',
      player2Rating: data['player2Rating'] as int? ?? 1200,
      boardSize: data['boardSize'] as int? ?? 19,
      ratingDiff: data['ratingDiff'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      gameId: data['gameId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'player1Uid': player1Uid,
      'player1DisplayName': player1DisplayName,
      'player1Rating': player1Rating,
      'player2Uid': player2Uid,
      'player2DisplayName': player2DisplayName,
      'player2Rating': player2Rating,
      'boardSize': boardSize,
      'ratingDiff': ratingDiff,
      'createdAt': Timestamp.fromDate(createdAt),
      'gameId': gameId,
    };
  }
}

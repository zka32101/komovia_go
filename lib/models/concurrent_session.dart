import 'package:cloud_firestore/cloud_firestore.dart';

/// いま対局中のプレイヤーのセッション（「同じ時間を過ごしている」縁を可視化する）
class ActivePlaySession {
  final String uid;
  final String displayName;
  final int boardSize;
  final String gameType;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;

  ActivePlaySession({
    required this.uid,
    required this.displayName,
    required this.boardSize,
    required this.gameType,
    required this.startedAt,
    required this.lastHeartbeatAt,
  });

  bool isStillActive({Duration staleAfter = const Duration(minutes: 5)}) {
    return DateTime.now().difference(lastHeartbeatAt) < staleAfter;
  }

  factory ActivePlaySession.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ActivePlaySession(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Player',
      boardSize: data['boardSize'] as int? ?? 19,
      gameType: data['gameType'] as String? ?? 'ai_game',
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastHeartbeatAt: data['lastHeartbeatAt'] != null
          ? (data['lastHeartbeatAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'boardSize': boardSize,
      'gameType': gameType,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastHeartbeatAt': Timestamp.fromDate(lastHeartbeatAt),
    };
  }
}

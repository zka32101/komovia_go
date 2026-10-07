/// フレンドのライブ対局アクティビティ（「いま友人が対局中」を表す）
class LiveFriendActivity {
  final String hostUid;
  final String hostDisplayName;
  final String sessionId;
  final String gameType;
  final int spectatorCount;
  final DateTime startedAt;

  LiveFriendActivity({
    required this.hostUid,
    required this.hostDisplayName,
    required this.sessionId,
    required this.gameType,
    required this.spectatorCount,
    required this.startedAt,
  });
}

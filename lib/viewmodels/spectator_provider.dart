import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';

final _logger = Logger();

final spectatorServiceProvider = Provider((ref) {
  final firestore = FirebaseFirestore.instance;
  return SpectatorService(firestore);
});

final activeSpectatorSessionsProvider = FutureProvider<List<SpectatorSession>>((ref) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final sessions = await service.getActiveSpectatorSessions();
    _logger.i('Fetched ${sessions.length} active spectator sessions');
    return sessions;
  } catch (e) {
    _logger.e('Error fetching active spectator sessions: $e');
    rethrow;
  }
});

final hostSpectatorSessionsProvider =
    FutureProvider.family<List<SpectatorSession>, String>((ref, hostUid) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final sessions = await service.getHostSpectatorSessions(hostUid);
    _logger.i('Fetched ${sessions.length} sessions for host $hostUid');
    return sessions;
  } catch (e) {
    _logger.e('Error fetching host spectator sessions: $e');
    rethrow;
  }
});

final gameSpectatorSessionsProvider =
    FutureProvider.family<List<SpectatorSession>, String>((ref, gameId) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final sessions = await service.getGameSpectatorSessions(gameId);
    _logger.i('Fetched ${sessions.length} sessions for game $gameId');
    return sessions;
  } catch (e) {
    _logger.e('Error fetching game spectator sessions: $e');
    rethrow;
  }
});

final spectatorSessionProvider =
    FutureProvider.family<SpectatorSession?, String>((ref, sessionId) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final session = await service.getSpectatorSession(sessionId);
    return session;
  } catch (e) {
    _logger.e('Error fetching spectator session: $e');
    rethrow;
  }
});

final spectatorCommentsProvider =
    FutureProvider.family<List<SpectatorComment>, String>((ref, sessionId) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final comments = await service.getSpectatorComments(sessionId);
    _logger.i('Fetched ${comments.length} comments for session $sessionId');
    return comments;
  } catch (e) {
    _logger.e('Error fetching spectator comments: $e');
    rethrow;
  }
});

final spectatorNotificationsProvider =
    FutureProvider.family<List<SpectatorNotification>, String>((ref, uid) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final notifications = await service.getSpectatorNotifications(uid);
    _logger.i('Fetched ${notifications.length} spectator notifications for $uid');
    return notifications;
  } catch (e) {
    _logger.e('Error fetching spectator notifications: $e');
    rethrow;
  }
});

final unreadSpectatorNotificationsProvider =
    FutureProvider.family<List<SpectatorNotification>, String>((ref, uid) async {
  final service = ref.watch(spectatorServiceProvider);
  try {
    final notifications = await service.getSpectatorNotifications(uid, unreadOnly: true);
    _logger.i('Fetched ${notifications.length} unread spectator notifications for $uid');
    return notifications;
  } catch (e) {
    _logger.e('Error fetching unread spectator notifications: $e');
    rethrow;
  }
});

final unreadSpectatorNotificationCountProvider =
    FutureProvider.family<int, String>((ref, uid) async {
  final notifications = await ref.watch(unreadSpectatorNotificationsProvider(uid).future);
  return notifications.length;
});

final createSpectatorSessionProvider = Provider((ref) {
  return (
    String gameId,
    String gameType,
    String hostUid,
    String hostDisplayName,
    bool isLive, {
    int boardSize = 19,
    String? coHostUid,
    String? id,
  }) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      final session = await service.createSpectatorSession(
        gameId: gameId,
        gameType: gameType,
        hostUid: hostUid,
        hostDisplayName: hostDisplayName,
        isLive: isLive,
        boardSize: boardSize,
        coHostUid: coHostUid,
        id: id,
      );
      _logger.i('Created spectator session: ${session.id}');
      return session;
    } catch (e) {
      _logger.e('Error creating spectator session: $e');
      rethrow;
    }
  };
});

/// 観戦者向け: 対局のライブ盤面をリアルタイムに購読する
final spectatorSessionStreamProvider =
    StreamProvider.family<SpectatorSession?, String>((ref, sessionId) {
  final service = ref.watch(spectatorServiceProvider);
  return service.streamSpectatorSession(sessionId);
});

/// ホスト側: 一手ごとに観戦セッションの盤面を更新する
final updateSpectatorBoardStateProvider = Provider((ref) {
  return (
    String sessionId,
    int moveIndex,
    List<List<int>> stones,
    bool isBlackTurn,
    int? lastMoveRow,
    int? lastMoveCol,
  ) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.updateBoardState(
        sessionId: sessionId,
        moveIndex: moveIndex,
        stones: stones,
        isBlackTurn: isBlackTurn,
        lastMoveRow: lastMoveRow,
        lastMoveCol: lastMoveCol,
      );
    } catch (e) {
      _logger.e('Error updating spectator board state: $e');
      rethrow;
    }
  };
});

final joinSpectatorSessionProvider = Provider((ref) {
  return (String sessionId, String spectatorUid) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.joinSpectatorSession(sessionId, spectatorUid);
      _logger.i('Joined spectator session: $sessionId');
    } catch (e) {
      _logger.e('Error joining spectator session: $e');
      rethrow;
    }
  };
});

final leaveSpectatorSessionProvider = Provider((ref) {
  return (String sessionId, String spectatorUid) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.leaveSpectatorSession(sessionId, spectatorUid);
      _logger.i('Left spectator session: $sessionId');
    } catch (e) {
      _logger.e('Error leaving spectator session: $e');
      rethrow;
    }
  };
});

final updateMoveIndexProvider = Provider((ref) {
  return (String sessionId, int moveIndex) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.updateMoveIndex(sessionId, moveIndex);
      _logger.i('Updated move index to $moveIndex for session $sessionId');
    } catch (e) {
      _logger.e('Error updating move index: $e');
      rethrow;
    }
  };
});

final endSpectatorSessionProvider = Provider((ref) {
  return (String sessionId) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.endSpectatorSession(sessionId);
      _logger.i('Ended spectator session: $sessionId');
    } catch (e) {
      _logger.e('Error ending spectator session: $e');
      rethrow;
    }
  };
});

final addSpectatorCommentProvider = Provider((ref) {
  return (
    String sessionId,
    String uid,
    String displayName,
    String comment,
    int moveIndex,
  ) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.addSpectatorComment(
        sessionId: sessionId,
        uid: uid,
        displayName: displayName,
        comment: comment,
        moveIndex: moveIndex,
      );
      _logger.i('Added spectator comment for session $sessionId');
    } catch (e) {
      _logger.e('Error adding spectator comment: $e');
      rethrow;
    }
  };
});

final likeSpectatorCommentProvider = Provider((ref) {
  return (String sessionId, String commentId, String uid) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.likeSpectatorComment(sessionId, commentId, uid);
      _logger.i('Liked spectator comment $commentId');
    } catch (e) {
      _logger.e('Error liking spectator comment: $e');
      rethrow;
    }
  };
});

final unlikeSpectatorCommentProvider = Provider((ref) {
  return (String sessionId, String commentId, String uid) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.unlikeSpectatorComment(sessionId, commentId, uid);
      _logger.i('Unliked spectator comment $commentId');
    } catch (e) {
      _logger.e('Error unliking spectator comment: $e');
      rethrow;
    }
  };
});

final sendSpectatorNotificationProvider = Provider((ref) {
  return (
    String uid,
    String title,
    String body, {
    String? spectatorSessionId,
    String? hostUid,
    String? hostDisplayName,
  }) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.sendSpectatorNotification(
        uid: uid,
        title: title,
        body: body,
        spectatorSessionId: spectatorSessionId,
        hostUid: hostUid,
        hostDisplayName: hostDisplayName,
      );
      _logger.i('Sent spectator notification to $uid');
    } catch (e) {
      _logger.e('Error sending spectator notification: $e');
      rethrow;
    }
  };
});

final markSpectatorNotificationAsReadProvider = Provider((ref) {
  return (String uid, String notificationId) async {
    final service = ref.watch(spectatorServiceProvider);
    try {
      await service.markSpectatorNotificationAsRead(uid, notificationId);
      _logger.i('Marked spectator notification $notificationId as read');
    } catch (e) {
      _logger.e('Error marking spectator notification as read: $e');
      rethrow;
    }
  };
});

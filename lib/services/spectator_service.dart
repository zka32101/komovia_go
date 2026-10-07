import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';

final _logger = Logger();

class SpectatorService {
  final FirebaseFirestore _firestore;

  SpectatorService(this._firestore);

  /// spectator_sessionsコレクションの新規ドキュメントIDを、何も書き込まずに
  /// 予約する。トーナメント戦PvP対局向け（PvpGameService.
  /// attachSpectatorSessionIfAbsentとの組み合わせで使う） — 実際に観戦
  /// セッションとして採用されるかどうかがそのトランザクションの結果次第
  /// なので、先にドキュメントを作ってしまうと負けた側の呼び出しが孤立した
  /// ドキュメントを残してしまう。IDだけなら未使用でも害はない。
  String reserveSessionId() => _firestore.collection('spectator_sessions').doc().id;

  Future<SpectatorSession> createSpectatorSession({
    required String gameId,
    required String gameType,
    required String hostUid,
    required String hostDisplayName,
    required bool isLive,
    int boardSize = 19,
    String? coHostUid,
    String? id,
  }) async {
    try {
      final docRef = id != null
          ? _firestore.collection('spectator_sessions').doc(id)
          : _firestore.collection('spectator_sessions').doc();
      final session = SpectatorSession(
        id: docRef.id,
        gameId: gameId,
        gameType: gameType,
        hostUid: hostUid,
        hostDisplayName: hostDisplayName,
        coHostUid: coHostUid,
        spectatorUids: [],
        spectatorCount: 0,
        moveIndex: 0,
        isLive: isLive,
        createdAt: DateTime.now(),
        boardSize: boardSize,
        stones: List.generate(boardSize, (_) => List.filled(boardSize, 0)),
      );
      await docRef.set(session.toFirestore());
      _logger.i('Created spectator session: ${docRef.id}');
      return session;
    } catch (e) {
      _logger.e('Error creating spectator session: $e');
      rethrow;
    }
  }

  Future<SpectatorSession?> getSpectatorSession(String sessionId) async {
    try {
      final doc = await _firestore.collection('spectator_sessions').doc(sessionId).get();
      if (!doc.exists) {
        _logger.w('Spectator session not found: $sessionId');
        return null;
      }
      return SpectatorSession.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error getting spectator session: $e');
      rethrow;
    }
  }

  /// 観戦者がリアルタイムに盤面を購読するためのストリーム
  Stream<SpectatorSession?> streamSpectatorSession(String sessionId) {
    return _firestore
        .collection('spectator_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => doc.exists ? SpectatorSession.fromFirestore(doc) : null);
  }

  /// 対局の一手ごとに盤面を同期する（ライブ観戦フレンド用）
  Future<void> updateBoardState({
    required String sessionId,
    required int moveIndex,
    required List<List<int>> stones,
    required bool isBlackTurn,
    int? lastMoveRow,
    int? lastMoveCol,
  }) async {
    try {
      await _firestore.collection('spectator_sessions').doc(sessionId).update({
        'moveIndex': moveIndex,
        // Firestore doesn't support arrays-of-arrays: encode each row as a
        // digit string ("0120...") instead of List<List<int>> (see
        // SpectatorSession.toFirestore/fromFirestore for the same encoding).
        'stones': stones.map((row) => row.join()).toList(),
        'isBlackTurn': isBlackTurn,
        'lastMoveRow': lastMoveRow,
        'lastMoveCol': lastMoveCol,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating board state: $e');
      rethrow;
    }
  }

  Future<List<SpectatorSession>> getActiveSpectatorSessions({int limit = 50}) async {
    try {
      final snapshots = await _firestore
          .collection('spectator_sessions')
          .where('endedAt', isNull: true)
          .where('isLive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshots.docs.map((doc) => SpectatorSession.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting active spectator sessions: $e');
      rethrow;
    }
  }

  Future<List<SpectatorSession>> getHostSpectatorSessions(String hostUid) async {
    try {
      final snapshots = await _firestore
          .collection('spectator_sessions')
          .where('hostUid', isEqualTo: hostUid)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshots.docs.map((doc) => SpectatorSession.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting host spectator sessions: $e');
      rethrow;
    }
  }

  Future<List<SpectatorSession>> getGameSpectatorSessions(String gameId) async {
    try {
      final snapshots = await _firestore
          .collection('spectator_sessions')
          .where('gameId', isEqualTo: gameId)
          .get();
      return snapshots.docs.map((doc) => SpectatorSession.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting game spectator sessions: $e');
      rethrow;
    }
  }

  Future<void> joinSpectatorSession(String sessionId, String spectatorUid) async {
    try {
      final docRef = _firestore.collection('spectator_sessions').doc(sessionId);
      await docRef.update({
        'spectatorUids': FieldValue.arrayUnion([spectatorUid]),
        'spectatorCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Spectator $spectatorUid joined session $sessionId');
    } catch (e) {
      _logger.e('Error joining spectator session: $e');
      rethrow;
    }
  }

  Future<void> leaveSpectatorSession(String sessionId, String spectatorUid) async {
    try {
      final docRef = _firestore.collection('spectator_sessions').doc(sessionId);
      await docRef.update({
        'spectatorUids': FieldValue.arrayRemove([spectatorUid]),
        'spectatorCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Spectator $spectatorUid left session $sessionId');
    } catch (e) {
      _logger.e('Error leaving spectator session: $e');
      rethrow;
    }
  }

  Future<void> updateMoveIndex(String sessionId, int moveIndex) async {
    try {
      await _firestore.collection('spectator_sessions').doc(sessionId).update({
        'moveIndex': moveIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating move index: $e');
      rethrow;
    }
  }

  Future<void> endSpectatorSession(String sessionId) async {
    try {
      await _firestore.collection('spectator_sessions').doc(sessionId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'isLive': false,
      });
      _logger.i('Ended spectator session: $sessionId');
    } catch (e) {
      _logger.e('Error ending spectator session: $e');
      rethrow;
    }
  }

  Future<void> addSpectatorComment({
    required String sessionId,
    required String uid,
    required String displayName,
    required String comment,
    required int moveIndex,
  }) async {
    try {
      final docRef = _firestore
          .collection('spectator_sessions')
          .doc(sessionId)
          .collection('comments')
          .doc();
      await docRef.set(SpectatorComment(
        id: docRef.id,
        spectatorSessionId: sessionId,
        uid: uid,
        displayName: displayName,
        comment: comment,
        moveIndex: moveIndex,
        createdAt: DateTime.now(),
        likes: [],
      ).toFirestore());
      _logger.i('Added spectator comment: ${docRef.id}');
    } catch (e) {
      _logger.e('Error adding spectator comment: $e');
      rethrow;
    }
  }

  Future<List<SpectatorComment>> getSpectatorComments(String sessionId) async {
    try {
      final snapshots = await _firestore
          .collection('spectator_sessions')
          .doc(sessionId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();
      return snapshots.docs.map((doc) => SpectatorComment.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting spectator comments: $e');
      rethrow;
    }
  }

  Future<void> likeSpectatorComment(
    String sessionId,
    String commentId,
    String uid,
  ) async {
    try {
      await _firestore
          .collection('spectator_sessions')
          .doc(sessionId)
          .collection('comments')
          .doc(commentId)
          .update({
        'likes': FieldValue.arrayUnion([uid]),
      });
      _logger.i('User $uid liked comment $commentId');
    } catch (e) {
      _logger.e('Error liking spectator comment: $e');
      rethrow;
    }
  }

  Future<void> unlikeSpectatorComment(
    String sessionId,
    String commentId,
    String uid,
  ) async {
    try {
      await _firestore
          .collection('spectator_sessions')
          .doc(sessionId)
          .collection('comments')
          .doc(commentId)
          .update({
        'likes': FieldValue.arrayRemove([uid]),
      });
      _logger.i('User $uid unliked comment $commentId');
    } catch (e) {
      _logger.e('Error unliking spectator comment: $e');
      rethrow;
    }
  }

  Future<void> sendSpectatorNotification({
    required String uid,
    required String title,
    required String body,
    String? spectatorSessionId,
    String? hostUid,
    String? hostDisplayName,
  }) async {
    try {
      final docRef = _firestore
          .collection('spectator_notifications')
          .doc(uid)
          .collection('messages')
          .doc();
      await docRef.set(SpectatorNotification(
        id: docRef.id,
        uid: uid,
        title: title,
        body: body,
        spectatorSessionId: spectatorSessionId,
        hostUid: hostUid,
        hostDisplayName: hostDisplayName,
        isRead: false,
        createdAt: DateTime.now(),
      ).toFirestore());
      _logger.i('Sent spectator notification to $uid');
    } catch (e) {
      _logger.e('Error sending spectator notification: $e');
      rethrow;
    }
  }

  Future<List<SpectatorNotification>> getSpectatorNotifications(
    String uid, {
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('spectator_notifications')
          .doc(uid)
          .collection('messages');

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      final snapshots = await query.orderBy('createdAt', descending: true).limit(limit).get();
      return snapshots.docs.map((doc) => SpectatorNotification.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting spectator notifications: $e');
      rethrow;
    }
  }

  Future<void> markSpectatorNotificationAsRead(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('spectator_notifications')
          .doc(uid)
          .collection('messages')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      _logger.i('Marked notification $notificationId as read');
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
      rethrow;
    }
  }
}

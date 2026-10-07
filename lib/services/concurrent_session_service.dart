import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';

final _logger = Logger();

/// 同時刻の碁盤 - いま同じ時間に対局しているプレイヤー達を可視化する
class ConcurrentSessionService {
  final FirebaseFirestore _firestore;

  static const Duration staleAfter = Duration(minutes: 5);

  ConcurrentSessionService(this._firestore);

  Future<void> startSession({
    required String uid,
    required String displayName,
    required int boardSize,
    required String gameType,
  }) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('active_play_sessions').doc(uid).set(
            ActivePlaySession(
              uid: uid,
              displayName: displayName,
              boardSize: boardSize,
              gameType: gameType,
              startedAt: now,
              lastHeartbeatAt: now,
            ).toFirestore(),
          );
      _logger.i('Started active play session for $uid');
    } catch (e) {
      _logger.e('Error starting active play session: $e');
      rethrow;
    }
  }

  /// 対局継続中であることを知らせる（クライアントから定期的に呼び出す）
  Future<void> heartbeat(String uid) async {
    try {
      await _firestore.collection('active_play_sessions').doc(uid).update({
        'lastHeartbeatAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      _logger.e('Error sending heartbeat: $e');
      rethrow;
    }
  }

  Future<void> endSession(String uid) async {
    try {
      await _firestore.collection('active_play_sessions').doc(uid).delete();
      _logger.i('Ended active play session for $uid');
    } catch (e) {
      _logger.e('Error ending active play session: $e');
      rethrow;
    }
  }

  /// いま同時に対局している他のプレイヤー一覧（古いハートビートは除外）
  Future<List<ActivePlaySession>> getConcurrentPlayers({String? excludeUid}) async {
    try {
      final cutoff = DateTime.now().subtract(staleAfter);
      final snapshots = await _firestore
          .collection('active_play_sessions')
          .where('lastHeartbeatAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .get();

      return snapshots.docs
          .map((doc) => ActivePlaySession.fromFirestore(doc))
          .where((session) => excludeUid == null || session.uid != excludeUid)
          .toList();
    } catch (e) {
      _logger.e('Error getting concurrent players: $e');
      rethrow;
    }
  }

  Future<int> getConcurrentPlayerCount() async {
    final players = await getConcurrentPlayers();
    return players.length;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';

final _logger = Logger();

/// 局面の轍 - 盤面局面をハッシュ化し、同じ局面に辿り着いた他ユーザーや
/// 名局（秀策の碁などcopyright-free kifu）との「縁」を検出する
class PositionEchoService {
  final FirebaseFirestore _firestore;

  PositionEchoService(this._firestore);

  /// 盤面を正規化した文字列ハッシュに変換する（同一局面なら常に同じハッシュ）
  String computePositionHash(BoardState board) {
    final buffer = StringBuffer('${board.boardSize}:');
    for (final row in board.stones) {
      buffer.write(row.join(''));
    }
    return buffer.toString();
  }

  /// 局面到達を記録し、同じ局面に到達済みの歴史的名局があれば紐付ける
  Future<PositionEcho> recordPositionReached({
    required String uid,
    required String displayName,
    required BoardState board,
    required int moveNumber,
  }) async {
    try {
      final hash = computePositionHash(board);
      final historicalMatch = await _findHistoricalMatch(hash);

      final docRef = _firestore.collection('position_echoes').doc();
      final echo = PositionEcho(
        id: docRef.id,
        positionHash: hash,
        uid: uid,
        displayName: displayName,
        kifuId: historicalMatch?.id,
        kifuTitle: historicalMatch?.getDisplayTitle(),
        moveNumber: moveNumber,
        boardSize: board.boardSize,
        reachedAt: DateTime.now(),
      );
      await docRef.set(echo.toFirestore());
      _logger.i('Recorded position echo for $uid (hash: ${hash.substring(0, 12)}...)');
      return echo;
    } catch (e) {
      _logger.e('Error recording position echo: $e');
      rethrow;
    }
  }

  /// 棋譜ライブラリの名局の中に同一局面（最終盤面）を持つものがあるか探す
  Future<KifuLibrary?> _findHistoricalMatch(String positionHash) async {
    try {
      final snapshots = await _firestore.collection('kifuLibrary').limit(200).get();
      for (final doc in snapshots.docs) {
        final kifu = KifuLibrary.fromFirestore(doc);
        try {
          final board = BoardState.fromSgf(kifu.sgfData);
          if (computePositionHash(board) == positionHash) {
            return kifu;
          }
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (e) {
      _logger.e('Error finding historical match: $e');
      return null;
    }
  }

  /// 同じ局面に到達した他のユーザー一覧（自分以外）を取得する
  Future<List<PositionEcho>> getUsersAtSamePosition(
    String positionHash, {
    String? excludeUid,
    int limit = 20,
  }) async {
    try {
      final snapshots = await _firestore
          .collection('position_echoes')
          .where('positionHash', isEqualTo: positionHash)
          .orderBy('reachedAt', descending: true)
          .limit(limit)
          .get();

      return snapshots.docs
          .map((doc) => PositionEcho.fromFirestore(doc))
          .where((echo) => excludeUid == null || echo.uid != excludeUid)
          .toList();
    } catch (e) {
      _logger.e('Error getting users at same position: $e');
      rethrow;
    }
  }

  /// あるユーザーが歴史的名局と同じ局面に到達した履歴を取得する
  Future<List<PositionEcho>> getHistoricalEchoes(String uid, {int limit = 50}) async {
    try {
      final snapshots = await _firestore
          .collection('position_echoes')
          .where('uid', isEqualTo: uid)
          .orderBy('reachedAt', descending: true)
          .limit(limit)
          .get();

      return snapshots.docs
          .map((doc) => PositionEcho.fromFirestore(doc))
          .where((echo) => echo.matchesHistoricalGame)
          .toList();
    } catch (e) {
      _logger.e('Error getting historical echoes: $e');
      rethrow;
    }
  }
}

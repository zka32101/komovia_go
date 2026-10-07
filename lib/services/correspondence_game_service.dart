import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/models/index.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Correspondence ゲームサービス - 手紙型ターン制対局
class CorrespondenceGameService {
  final FirebaseFirestore _firestore;

  CorrespondenceGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Correspondence ゲームを開始
  Future<CorrespondenceGameRecord> startCorrespondenceGame({
    required String uid,
    required String opponentUid,
    required int boardSize,
    int timePerMoveHours = 24,
  }) async {
    try {
      _logger.i(
        'Starting Correspondence game - '
        'uid: $uid, opponent: $opponentUid, boardSize: $boardSize',
      );

      final now = DateTime.now();
      final gameId = _firestore.collection('correspondenceGames').doc().id;

      final game = CorrespondenceGameRecord(
        id: gameId,
        uid: uid,
        opponentUid: opponentUid,
        boardSize: boardSize,
        startDate: now,
        endDate: null,
        currentTurnNumber: 0,
        currentPlayerColor: 'black', // 黒が最初
        status: 'active',
        moveHistory: [],
        lastMoveAt: now,
        result: 'abandoned',
        winnerColor: null,
        sgfData: '',
        timePerMoveHours: timePerMoveHours,
        createdAt: now,
      );

      await _firestore
          .collection('correspondenceGames')
          .doc(gameId)
          .set(game.toJson());

      // 相手に通知を送信
      await _sendGameNotification(
        recipientUid: opponentUid,
        gameId: gameId,
        gameType: 'correspondence',
        senderUid: uid,
        message: '$uid さんが手紙型対局を開始しました',
      );

      _logger.i('Correspondence game created: $gameId');
      return game;
    } catch (e) {
      _logger.e('Error starting Correspondence game: $e');
      rethrow;
    }
  }

  /// Correspondence ゲームに手を追加
  Future<void> addMoveToGame({
    required String gameId,
    required String move,
    required String playerColor,
  }) async {
    try {
      _logger.i('Adding move to Correspondence game: $gameId');

      final gameDoc =
          await _firestore.collection('correspondenceGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = CorrespondenceGameRecord.fromJson(gameDoc.data()!);

      // ターンプレイヤーの確認
      if (game.currentPlayerColor == playerColor) {
        throw Exception('Invalid player turn');
      }

      // 次のターンプレイヤーを決定
      final nextPlayerColor = playerColor == 'black' ? 'white' : 'black';

      await _firestore.collection('correspondenceGames').doc(gameId).update({
        'moveHistory': FieldValue.arrayUnion([move]),
        'currentTurnNumber': game.currentTurnNumber + 1,
        'currentPlayerColor': nextPlayerColor,
        'lastMoveAt': DateTime.now().toIso8601String(),
      });

      _logger.i('Move added successfully');
    } catch (e) {
      _logger.e('Error adding move: $e');
      rethrow;
    }
  }

  /// Correspondence ゲームを終了
  Future<CorrespondenceGameRecord> endCorrespondenceGame({
    required String gameId,
    required String result,
    required String? winnerColor,
    required String sgfData,
  }) async {
    try {
      _logger.i('Ending Correspondence game: $gameId, result: $result');

      final gameDoc =
          await _firestore.collection('correspondenceGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = CorrespondenceGameRecord.fromJson(gameDoc.data()!);
      final now = DateTime.now();

      final updatedGame = game.copyWith(
        endDate: now,
        status: 'completed',
        result: result,
        winnerColor: winnerColor,
        sgfData: sgfData,
      );

      await _firestore
          .collection('correspondenceGames')
          .doc(gameId)
          .set(updatedGame.toJson());

      // 相手に結果を通知
      await _sendGameNotification(
        recipientUid: game.opponentUid,
        gameId: gameId,
        gameType: 'correspondence_result',
        senderUid: game.uid,
        message: '手紙型対局が終了しました。結果: $result',
      );

      _logger.i('Correspondence game ended');
      return updatedGame;
    } catch (e) {
      _logger.e('Error ending Correspondence game: $e');
      rethrow;
    }
  }

  /// ゲームを放棄
  Future<void> abandonGame({required String gameId}) async {
    try {
      _logger.i('Abandoning game: $gameId');

      final gameDoc =
          await _firestore.collection('correspondenceGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = CorrespondenceGameRecord.fromJson(gameDoc.data()!);

      await _firestore.collection('correspondenceGames').doc(gameId).update({
        'status': 'abandoned',
        'result': 'abandoned',
        'endDate': DateTime.now().toIso8601String(),
      });

      // 相手に通知
      await _sendGameNotification(
        recipientUid: game.opponentUid,
        gameId: gameId,
        gameType: 'correspondence_abandoned',
        senderUid: game.uid,
        message: '対局が放棄されました',
      );

      _logger.i('Game abandoned');
    } catch (e) {
      _logger.e('Error abandoning game: $e');
      rethrow;
    }
  }

  /// ユーザーの Correspondence ゲーム一覧を取得
  Future<List<CorrespondenceGameRecord>> getUserCorrespondenceGames({
    required String uid,
    String status = 'active', // 'active', 'completed', 'all'
  }) async {
    try {
      _logger.i('Fetching Correspondence games for user: $uid, status: $status');

      Query query = _firestore
          .collection('correspondenceGames')
          .where('uid', isEqualTo: uid)
          .orderBy('lastMoveAt', descending: true);

      if (status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();

      final games = snapshot.docs
          .map((doc) => CorrespondenceGameRecord.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      _logger.i('Fetched ${games.length} Correspondence games');
      return games;
    } catch (e) {
      _logger.e('Error fetching Correspondence games: $e');
      rethrow;
    }
  }

  /// 待機中の手を数える（相手の番のゲーム）
  Future<int> getPendingMoveCount({required String uid}) async {
    try {
      _logger.i('Counting pending moves for user: $uid');

      // uid が currentPlayerColor の色でプレイしているゲーム
      // ただし、API の制限により OR クエリが直接できないため、複数のクエリを組み合わせ
      final blackTurn = await _firestore
          .collection('correspondenceGames')
          .where('opponentUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .where('currentPlayerColor', isEqualTo: 'black')
          .count()
          .get();

      final whiteTurn = await _firestore
          .collection('correspondenceGames')
          .where('opponentUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .where('currentPlayerColor', isEqualTo: 'white')
          .count()
          .get();

      final count = (blackTurn.count ?? 0) + (whiteTurn.count ?? 0);
      _logger.i('Pending moves: $count');
      return count;
    } catch (e) {
      _logger.e('Error counting pending moves: $e');
      rethrow;
    }
  }

  /// ゲーム通知を送信
  ///
  /// Writes to `notifications/{uid}/messages/{id}` (the shape
  /// NotificationService/notification_provider.dart actually read for the
  /// notification bell) rather than a flat `notifications/{autoId}` doc
  /// with a `recipientUid` field — that shape was never read by anything,
  /// so these notifications silently never reached the UI.
  Future<void> _sendGameNotification({
    required String recipientUid,
    required String gameId,
    required String gameType,
    required String senderUid,
    required String message,
  }) async {
    try {
      final docRef = _firestore
          .collection('notifications')
          .doc(recipientUid)
          .collection('messages')
          .doc();

      final notification = AppNotification(
        id: docRef.id,
        uid: recipientUid,
        title: '通信対局',
        body: message,
        data: {'gameId': gameId, 'gameType': gameType, 'senderUid': senderUid},
        type: 'correspondence_game',
        isRead: false,
        createdAt: DateTime.now(),
      );

      await docRef.set(notification.toFirestore());

      _logger.i('Notification sent: ${docRef.id}');
    } catch (e) {
      _logger.e('Error sending notification: $e');
      // 通知送信エラーは致命的ではないので rethrow しない
    }
  }
}

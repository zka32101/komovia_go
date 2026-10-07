import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/models/index.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Blitz ゲームサービス - 5分急速戦
class BlitzGameService {
  final FirebaseFirestore _firestore;

  BlitzGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Blitz ゲームを開始
  /// [uid] - ユーザーID
  /// [boardSize] - ボード サイズ (9, 13, 19)
  /// [aiLevel] - AI レベル (null なら対人戦)
  /// [opponentUid] - 対人戦の相手 ID
  Future<BlitzGameRecord> startBlitzGame({
    required String uid,
    required int boardSize,
    String? aiLevel,
    required String opponentUid,
  }) async {
    try {
      _logger.i('Starting Blitz game - uid: $uid, boardSize: $boardSize');

      final now = DateTime.now();
      final gameId = _firestore.collection('blitzGames').doc().id;

      final game = BlitzGameRecord(
        id: gameId,
        uid: uid,
        boardSize: boardSize,
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
        aiLevel: aiLevel,
        opponentUid: opponentUid,
        whitePlayer: uid, // 常にユーザーが白
        blackPlayer: aiLevel != null ? 'ai' : opponentUid,
        result: 'draw',
        winnerColor: 'draw',
        moveHistory: [],
        sgfData: '',
        ratingChange: 0,
        createdAt: now,
      );

      await _firestore
          .collection('blitzGames')
          .doc(gameId)
          .set(game.toJson());

      _logger.i('Blitz game created: $gameId');
      return game;
    } catch (e) {
      _logger.e('Error starting Blitz game: $e');
      rethrow;
    }
  }

  /// Blitz ゲームに手を追加
  Future<void> addMove({
    required String gameId,
    required String move,
    required String playerColor,
  }) async {
    try {
      _logger.i('Adding move to Blitz game: $gameId, move: $move');

      await _firestore.collection('blitzGames').doc(gameId).update({
        'moveHistory': FieldValue.arrayUnion([move]),
      });

      _logger.i('Move added successfully');
    } catch (e) {
      _logger.e('Error adding move: $e');
      rethrow;
    }
  }

  /// Blitz ゲームを終了
  Future<BlitzGameRecord> endBlitzGame({
    required String gameId,
    required String result, // 'win', 'loss', 'draw'
    required String winnerColor,
    required String sgfData,
    required int ratingChange,
  }) async {
    try {
      _logger.i('Ending Blitz game: $gameId, result: $result');

      final now = DateTime.now();
      final gameDoc = await _firestore.collection('blitzGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = BlitzGameRecord.fromJson(gameDoc.data()!);
      final duration = now.difference(game.startedAt).inSeconds;

      final updatedGame = game.copyWith(
        endedAt: now,
        durationSeconds: duration,
        result: result,
        winnerColor: winnerColor,
        sgfData: sgfData,
        ratingChange: ratingChange,
      );

      await _firestore
          .collection('blitzGames')
          .doc(gameId)
          .set(updatedGame.toJson());

      _logger.i('Blitz game ended successfully');
      return updatedGame;
    } catch (e) {
      _logger.e('Error ending Blitz game: $e');
      rethrow;
    }
  }

  /// ユーザーの Blitz ゲーム履歴を取得
  Future<List<BlitzGameRecord>> getUserBlitzHistory({
    required String uid,
    int limit = 20,
  }) async {
    try {
      _logger.i('Fetching Blitz history for user: $uid');

      final snapshot = await _firestore
          .collection('blitzGames')
          .where('uid', isEqualTo: uid)
          .orderBy('endedAt', descending: true)
          .limit(limit)
          .get();

      final games = snapshot.docs
          .map((doc) => BlitzGameRecord.fromJson(doc.data()))
          .toList();

      _logger.i('Fetched ${games.length} Blitz games');
      return games;
    } catch (e) {
      _logger.e('Error fetching Blitz history: $e');
      rethrow;
    }
  }

  /// Blitz 統計情報を取得
  Future<BlitzStats> getUserBlitzStats({required String uid}) async {
    try {
      _logger.i('Fetching Blitz stats for user: $uid');

      final snapshot = await _firestore
          .collection('blitzGames')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      int wins = 0;
      int losses = 0;
      int draws = 0;
      int totalGames = 0;
      int totalRatingChange = 0;
      int totalDuration = 0;

      for (final doc in snapshot.docs) {
        final game = BlitzGameRecord.fromJson(doc.data());
        totalGames++;
        totalRatingChange += game.ratingChange;
        totalDuration += game.durationSeconds;

        if (game.result == 'win') {
          wins++;
        } else if (game.result == 'loss') {
          losses++;
        } else {
          draws++;
        }
      }

      final stats = BlitzStats(
        totalGames: totalGames,
        wins: wins,
        losses: losses,
        draws: draws,
        winRate: totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '0.0',
        totalRatingChange: totalRatingChange,
        averageDuration: totalGames > 0 ? totalDuration ~/ totalGames : 0,
      );

      _logger.i('Blitz stats: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error fetching Blitz stats: $e');
      rethrow;
    }
  }
}

/// Blitz 統計情報
class BlitzStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final String winRate;
  final int totalRatingChange;
  final int averageDuration;

  BlitzStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.totalRatingChange,
    required this.averageDuration,
  });

  @override
  String toString() => 'BlitzStats('
      'totalGames: $totalGames, '
      'wins: $wins, '
      'losses: $losses, '
      'draws: $draws, '
      'winRate: $winRate%, '
      'totalRatingChange: $totalRatingChange, '
      'averageDuration: $averageDuration)';
}

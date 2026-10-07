import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';

final _logger = Logger();

/// 実力マッチングEngine - レート差の近いプレイヤー同士を「運命の対戦」として結びつける
class MatchingService {
  final FirebaseFirestore _firestore;

  /// マッチ判定の許容レート差（この範囲内なら「縁がある」と判定）
  static const int maxRatingDiff = 200;

  MatchingService(this._firestore);

  Future<void> joinQueue({
    required String uid,
    required String displayName,
    required int rating,
    required int boardSize,
  }) async {
    try {
      await _firestore.collection('matchmaking_queue').doc(uid).set(
            MatchmakingQueueEntry(
              uid: uid,
              displayName: displayName,
              rating: rating,
              boardSize: boardSize,
              queuedAt: DateTime.now(),
              status: 'waiting',
            ).toFirestore(),
          );
      _logger.i('User $uid joined matchmaking queue (rating: $rating, boardSize: $boardSize)');
    } catch (e) {
      _logger.e('Error joining matchmaking queue: $e');
      rethrow;
    }
  }

  Future<void> leaveQueue(String uid) async {
    try {
      await _firestore.collection('matchmaking_queue').doc(uid).delete();
      _logger.i('User $uid left matchmaking queue');
    } catch (e) {
      _logger.e('Error leaving matchmaking queue: $e');
      rethrow;
    }
  }

  /// レート差が最も近い待機中プレイヤーを探し、マッチが見つかれば成立させる。
  ///
  /// 候補者選定（誰が一番近いか）はコレクションクエリが必要なため
  /// トランザクション外で行うが、実際にマッチを成立させる書き込みは
  /// トランザクション内で候補者の状態を再確認してから行う。これにより、
  /// 2人のユーザーがほぼ同時に同じ候補者を見つけても、片方だけが
  /// マッチを成立させ、もう片方は「見つからなかった」扱いになる
  /// （既に'matched'になった候補者を二重に予約することがない）。
  Future<MatchResult?> findMatch({
    required String uid,
    required String displayName,
    required int rating,
    required int boardSize,
  }) async {
    try {
      final snapshots = await _firestore
          .collection('matchmaking_queue')
          .where('boardSize', isEqualTo: boardSize)
          .where('status', isEqualTo: 'waiting')
          .get();

      MatchmakingQueueEntry? bestCandidate;
      int bestDiff = 1 << 30;

      for (final doc in snapshots.docs) {
        if (doc.id == uid) continue;
        final entry = MatchmakingQueueEntry.fromFirestore(doc);
        final diff = (entry.rating - rating).abs();
        if (diff <= maxRatingDiff && diff < bestDiff) {
          bestCandidate = entry;
          bestDiff = diff;
        }
      }

      if (bestCandidate == null) {
        _logger.i('No compatible match found for $uid yet');
        return null;
      }

      final selectedCandidate = bestCandidate;
      final selectedDiff = bestDiff;
      final selfRef = _firestore.collection('matchmaking_queue').doc(uid);
      final candidateRef = _firestore.collection('matchmaking_queue').doc(selectedCandidate.uid);
      final matchRef = _firestore.collection('match_results').doc();

      final match = await _firestore.runTransaction<MatchResult?>((transaction) async {
        final selfDoc = await transaction.get(selfRef);
        final candidateDoc = await transaction.get(candidateRef);
        final selfStatus = selfDoc.data()?['status'] as String?;
        final candidateStatus = candidateDoc.data()?['status'] as String?;

        if (selfStatus != 'waiting' || candidateStatus != 'waiting') {
          _logger.i(
            'Match candidate no longer available (self=$selfStatus, candidate=$candidateStatus)',
          );
          return null;
        }

        final result = MatchResult(
          id: matchRef.id,
          player1Uid: uid,
          player1DisplayName: displayName,
          player1Rating: rating,
          player2Uid: selectedCandidate.uid,
          player2DisplayName: selectedCandidate.displayName,
          player2Rating: selectedCandidate.rating,
          boardSize: boardSize,
          ratingDiff: selectedDiff,
          createdAt: DateTime.now(),
        );

        transaction.set(matchRef, result.toFirestore());
        transaction.update(selfRef, {'status': 'matched'});
        transaction.update(candidateRef, {'status': 'matched'});
        return result;
      });

      if (match == null) {
        return null;
      }

      _logger.i('Match found: $uid <-> ${selectedCandidate.uid} (rating diff: $selectedDiff)');
      return match;
    } catch (e) {
      _logger.e('Error finding match: $e');
      rethrow;
    }
  }

  Future<List<MatchResult>> getMatchHistory(String uid, {int limit = 50}) async {
    try {
      final p1Snapshots = await _firestore
          .collection('match_results')
          .where('player1Uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final p2Snapshots = await _firestore
          .collection('match_results')
          .where('player2Uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final matches = [
        ...p1Snapshots.docs.map((doc) => MatchResult.fromFirestore(doc)),
        ...p2Snapshots.docs.map((doc) => MatchResult.fromFirestore(doc)),
      ];
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matches.take(limit).toList();
    } catch (e) {
      _logger.e('Error getting match history: $e');
      rethrow;
    }
  }

  Future<void> attachGameToMatch(String matchId, String gameId) async {
    try {
      await _firestore.collection('match_results').doc(matchId).update({'gameId': gameId});
      _logger.i('Attached game $gameId to match $matchId');
    } catch (e) {
      _logger.e('Error attaching game to match: $e');
      rethrow;
    }
  }
}

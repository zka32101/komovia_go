import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/models/index.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Puzzle Rush サービス - タイム制マラソン
class PuzzleRushService {
  final FirebaseFirestore _firestore;

  PuzzleRushService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Puzzle Rush セッションを開始
  Future<PuzzleRushRecord> startPuzzleRush({
    required String uid,
    required String difficulty, // 'easy', 'normal', 'hard', 'expert'
  }) async {
    try {
      _logger.i('Starting Puzzle Rush - uid: $uid, difficulty: $difficulty');

      final now = DateTime.now();
      final sessionId = _firestore.collection('puzzleRushSessions').doc().id;

      final session = PuzzleRushRecord(
        id: sessionId,
        uid: uid,
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
        solvedCount: 0,
        correctCount: 0,
        totalAttempts: 0,
        score: 0,
        maxCombo: 0,
        averageSolveTime: 0,
        difficulty: difficulty,
        puzzleIds: [],
        puzzleDifficulties: [],
        puzzleResults: [],
        solveTimes: [],
        createdAt: now,
      );

      await _firestore
          .collection('puzzleRushSessions')
          .doc(sessionId)
          .set(session.toJson());

      _logger.i('Puzzle Rush session created: $sessionId');
      return session;
    } catch (e) {
      _logger.e('Error starting Puzzle Rush: $e');
      rethrow;
    }
  }

  /// パズルを解く
  /// [isCorrect] - 正解したか
  /// [solveTime] - 解答時間（秒）
  Future<void> solvePuzzle({
    required String sessionId,
    required String puzzleId,
    required int puzzleDifficulty,
    required bool isCorrect,
    required int solveTime,
  }) async {
    try {
      _logger.i(
        'Solving puzzle - sessionId: $sessionId, '
        'puzzleId: $puzzleId, isCorrect: $isCorrect, solveTime: ${solveTime}s',
      );

      final sessionDoc =
          await _firestore.collection('puzzleRushSessions').doc(sessionId).get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found: $sessionId');
      }

      final session = PuzzleRushRecord.fromJson(sessionDoc.data()!);

      // スコア計算：難易度係数 × 正解フラグ
      final difficultyMultiplier = _getDifficultyMultiplier(puzzleDifficulty);
      final pointsEarned = isCorrect ? (10 * difficultyMultiplier).toInt() : 0;

      // コンボの計算
      int newMaxCombo = session.maxCombo;
      if (isCorrect) {
        newMaxCombo = (session.puzzleResults.isEmpty
                ? 1
                : (session.puzzleResults.last ? session.maxCombo + 1 : 1))
            .toInt();
      }

      // 平均解答時間を更新
      final newAverageSolveTime = session.solveTimes.isEmpty
          ? solveTime.toDouble()
          : (session.solveTimes.fold<int>(0, (a, b) => a + b) + solveTime) /
              (session.solveTimes.length + 1);

      await _firestore
          .collection('puzzleRushSessions')
          .doc(sessionId)
          .update({
        'puzzleIds': FieldValue.arrayUnion([puzzleId]),
        'puzzleDifficulties': FieldValue.arrayUnion([puzzleDifficulty]),
        'puzzleResults': FieldValue.arrayUnion([isCorrect]),
        'solveTimes': FieldValue.arrayUnion([solveTime]),
        'score': session.score + pointsEarned,
        'solvedCount': session.solvedCount + 1,
        'correctCount': isCorrect ? session.correctCount + 1 : session.correctCount,
        'totalAttempts': session.totalAttempts + 1,
        'maxCombo': newMaxCombo,
        'averageSolveTime': newAverageSolveTime,
      });

      _logger.i('Puzzle solved successfully');
    } catch (e) {
      _logger.e('Error solving puzzle: $e');
      rethrow;
    }
  }

  /// Puzzle Rush セッションを終了
  Future<PuzzleRushRecord> endPuzzleRush({
    required String sessionId,
  }) async {
    try {
      _logger.i('Ending Puzzle Rush session: $sessionId');

      final sessionDoc =
          await _firestore.collection('puzzleRushSessions').doc(sessionId).get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found: $sessionId');
      }

      final session = PuzzleRushRecord.fromJson(sessionDoc.data()!);
      final now = DateTime.now();
      final duration = now.difference(session.startedAt).inSeconds;

      final updatedSession = session.copyWith(
        endedAt: now,
        durationSeconds: duration,
      );

      await _firestore
          .collection('puzzleRushSessions')
          .doc(sessionId)
          .set(updatedSession.toJson());

      // リーダーボードを更新
      await _updateLeaderboard(session: updatedSession);

      _logger.i('Puzzle Rush session ended');
      return updatedSession;
    } catch (e) {
      _logger.e('Error ending Puzzle Rush: $e');
      rethrow;
    }
  }

  /// ユーザーの Puzzle Rush 履歴を取得
  Future<List<PuzzleRushRecord>> getUserPuzzleRushHistory({
    required String uid,
    int limit = 20,
  }) async {
    try {
      _logger.i('Fetching Puzzle Rush history for user: $uid');

      final snapshot = await _firestore
          .collection('puzzleRushSessions')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final sessions = snapshot.docs
          .map((doc) => PuzzleRushRecord.fromJson(doc.data()))
          .toList();

      _logger.i('Fetched ${sessions.length} Puzzle Rush sessions');
      return sessions;
    } catch (e) {
      _logger.e('Error fetching Puzzle Rush history: $e');
      rethrow;
    }
  }

  /// Puzzle Rush 統計情報を取得
  Future<PuzzleRushStats> getUserPuzzleRushStats({
    required String uid,
  }) async {
    try {
      _logger.i('Fetching Puzzle Rush stats for user: $uid');

      final sessions = await getUserPuzzleRushHistory(uid: uid, limit: 100);

      int totalSessions = sessions.length;
      int totalScore = 0;
      int totalSolved = 0;
      int totalCorrect = 0;
      int highestScore = 0;
      double averageSolveTime = 0;

      for (final session in sessions) {
        totalScore += session.score;
        totalSolved += session.solvedCount;
        totalCorrect += session.correctCount;
        highestScore = highestScore > session.score ? highestScore : session.score;
        averageSolveTime += session.averageSolveTime;
      }

      if (totalSessions > 0) {
        averageSolveTime /= totalSessions;
      }

      final accuracy = totalSolved > 0
          ? ((totalCorrect / totalSolved) * 100).toStringAsFixed(1)
          : '0.0';

      final stats = PuzzleRushStats(
        totalSessions: totalSessions,
        totalScore: totalScore,
        averageScore: totalSessions > 0 ? (totalScore / totalSessions).toInt() : 0,
        highestScore: highestScore,
        totalSolved: totalSolved,
        totalCorrect: totalCorrect,
        accuracy: accuracy,
        averageSolveTime: averageSolveTime,
      );

      _logger.i('Puzzle Rush stats: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error fetching Puzzle Rush stats: $e');
      rethrow;
    }
  }

  /// グローバルリーダーボードを取得
  Future<List<PuzzleRushLeaderboardEntry>> getLeaderboard({
    required String difficulty,
    int limit = 100,
  }) async {
    try {
      _logger.i('Fetching Puzzle Rush leaderboard - difficulty: $difficulty');

      final snapshot = await _firestore
          .collection('puzzleRushLeaderboard')
          .where('difficulty', isEqualTo: difficulty)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      final entries = snapshot.docs
          .map((doc) => PuzzleRushLeaderboardEntry.fromJson(doc.data()))
          .toList();

      _logger.i('Fetched ${entries.length} leaderboard entries');
      return entries;
    } catch (e) {
      _logger.e('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// リーダーボードを更新
  Future<void> _updateLeaderboard({required PuzzleRushRecord session}) async {
    try {
      _logger.i('Updating leaderboard for session: ${session.id}');

      // ユーザーの既存エントリを取得
      final existingQuery = await _firestore
          .collection('puzzleRushLeaderboard')
          .where('uid', isEqualTo: session.uid)
          .where('difficulty', isEqualTo: session.difficulty)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final existingEntry =
            PuzzleRushLeaderboardEntry.fromJson(existingQuery.docs.first.data());

        // より高いスコアのみ更新
        if (session.score > existingEntry.score) {
          await _firestore
              .collection('puzzleRushLeaderboard')
              .doc(existingQuery.docs.first.id)
              .update({
                'score': session.score,
                'solvedCount': session.solvedCount,
                'accuracy': (session.correctCount / session.solvedCount * 100)
                    .toStringAsFixed(1),
                'updatedAt': DateTime.now(),
              });
          _logger.i('Leaderboard entry updated');
        }
      } else {
        // 新規エントリを作成
        final entryId = _firestore.collection('puzzleRushLeaderboard').doc().id;
        final accuracy = session.solvedCount > 0
            ? ((session.correctCount / session.solvedCount) * 100)
                .toStringAsFixed(1)
            : '0.0';

        await _firestore
            .collection('puzzleRushLeaderboard')
            .doc(entryId)
            .set({
              'uid': session.uid,
              'difficulty': session.difficulty,
              'score': session.score,
              'solvedCount': session.solvedCount,
              'accuracy': accuracy,
              'createdAt': DateTime.now(),
              'updatedAt': DateTime.now(),
            });
        _logger.i('Leaderboard entry created');
      }
    } catch (e) {
      _logger.e('Error updating leaderboard: $e');
      // リーダーボード更新エラーは致命的ではないので rethrow しない
    }
  }

  /// 難易度係数を取得
  int _getDifficultyMultiplier(int difficulty) {
    switch (difficulty) {
      case 1:
        return 1; // easy
      case 2:
        return 2; // normal
      case 3:
        return 3; // hard
      case 4:
        return 5; // expert
      default:
        return 1;
    }
  }
}

/// Puzzle Rush 統計情報
class PuzzleRushStats {
  final int totalSessions;
  final int totalScore;
  final int averageScore;
  final int highestScore;
  final int totalSolved;
  final int totalCorrect;
  final String accuracy;
  final double averageSolveTime;

  PuzzleRushStats({
    required this.totalSessions,
    required this.totalScore,
    required this.averageScore,
    required this.highestScore,
    required this.totalSolved,
    required this.totalCorrect,
    required this.accuracy,
    required this.averageSolveTime,
  });

  @override
  String toString() => 'PuzzleRushStats('
      'totalSessions: $totalSessions, '
      'totalScore: $totalScore, '
      'averageScore: $averageScore, '
      'highestScore: $highestScore, '
      'totalSolved: $totalSolved, '
      'totalCorrect: $totalCorrect, '
      'accuracy: $accuracy%, '
      'averageSolveTime: ${averageSolveTime.toStringAsFixed(2)}s)';
}

/// Puzzle Rush リーダーボードエントリ
class PuzzleRushLeaderboardEntry {
  final String uid;
  final String difficulty;
  final int score;
  final int solvedCount;
  final String accuracy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PuzzleRushLeaderboardEntry({
    required this.uid,
    required this.difficulty,
    required this.score,
    required this.solvedCount,
    required this.accuracy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PuzzleRushLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return PuzzleRushLeaderboardEntry(
      uid: json['uid'] as String,
      difficulty: json['difficulty'] as String,
      score: json['score'] as int,
      solvedCount: json['solvedCount'] as int,
      accuracy: json['accuracy'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'difficulty': difficulty,
        'score': score,
        'solvedCount': solvedCount,
        'accuracy': accuracy,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  @override
  String toString() => 'PuzzleRushLeaderboardEntry('
      'uid: $uid, '
      'score: $score, '
      'solvedCount: $solvedCount, '
      'accuracy: $accuracy%)';
}

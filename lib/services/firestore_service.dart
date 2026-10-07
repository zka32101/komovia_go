import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';

/// Service for Firestore database operations
/// Handles CRUD for all data models with error handling
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  // Collection names
  static const String usersCollection = 'users';
  static const String gameRecordsCollection = 'gameRecords';
  static const String tsumeGoProblemsCollection = 'tsumeGoProblems';
  static const String userTsumeGoLogsCollection = 'userTsumeGoLogs';
  static const String kifuLibraryCollection = 'kifuLibrary';
  static const String observationLogsCollection = 'observationLogs';

  // ================== USER OPERATIONS ==================

  /// Get user profile by UID
  Future<User?> getUser(String uid) async {
    try {
      _logger.i('Fetching user: $uid');
      final doc = await _firestore.collection(usersCollection).doc(uid).get();

      if (!doc.exists) {
        _logger.w('User not found: $uid');
        return null;
      }

      return User.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching user: $e');
      rethrow;
    }
  }

  /// Create or update user profile
  Future<void> saveUser(User user) async {
    try {
      _logger.i('Saving user: ${user.uid}');
      await _firestore
          .collection(usersCollection)
          .doc(user.uid)
          .set(user.toFirestore(), SetOptions(merge: true));
      _logger.i('✅ User saved successfully');
    } catch (e) {
      _logger.e('Error saving user: $e');
      rethrow;
    }
  }

  /// Increment games played count (atomic operation)
  Future<void> incrementGamesPlayed(String uid) async {
    try {
      _logger.i('Incrementing games played for: $uid');
      await _firestore
          .collection(usersCollection)
          .doc(uid)
          .update({'gamesPlayedCount': FieldValue.increment(1)});
      _logger.i('✅ Games count incremented');
    } catch (e) {
      _logger.e('Error incrementing games: $e');
      rethrow;
    }
  }

  // ================== GAME RECORD OPERATIONS ==================

  /// Save completed game record
  Future<String> saveGameRecord(GameRecord gameRecord) async {
    try {
      _logger.i('Saving game record for user: ${gameRecord.uid}');
      final docRef = await _firestore
          .collection(gameRecordsCollection)
          .add(gameRecord.toFirestore());
      _logger.i('✅ Game record saved: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error saving game record: $e');
      rethrow;
    }
  }

  /// Get game record by ID
  Future<GameRecord?> getGameRecord(String gameId) async {
    try {
      _logger.i('Fetching game record: $gameId');
      final doc = await _firestore
          .collection(gameRecordsCollection)
          .doc(gameId)
          .get();

      if (!doc.exists) {
        _logger.w('Game record not found: $gameId');
        return null;
      }

      return GameRecord.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching game record: $e');
      rethrow;
    }
  }

  /// Get user's game history (paginated)
  Future<List<GameRecord>> getUserGameRecords(String uid, {int limit = 10}) async {
    try {
      _logger.i('Fetching game records for user: $uid (limit: $limit)');
      final query = await _firestore
          .collection(gameRecordsCollection)
          .where('uid', isEqualTo: uid)
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => GameRecord.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching game records: $e');
      rethrow;
    }
  }

  // ================== TSUME-GO PROBLEM OPERATIONS ==================

  /// Get today's tsume-go problem
  /// Implementation: rotate through problems by version/difficulty
  Future<TsumeGoProblem?> getTodaysTsumeProblem() async {
    try {
      _logger.i('Fetching today\'s tsume-go problem');
      final now = DateTime.now();
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

      // Use day of year as seed for problem selection (deterministic)
      final difficulty = (dayOfYear % 5) + 1; // 1-5 difficulty cycle

      final query = await _firestore
          .collection(tsumeGoProblemsCollection)
          .where('difficulty', isEqualTo: difficulty)
          .limit(10)
          .get();

      if (query.docs.isEmpty) {
        _logger.w('No tsume-go problems found for difficulty: $difficulty');
        return null;
      }

      // Pick one based on day (pseudo-random but deterministic)
      final problemIndex = dayOfYear % query.docs.length;
      return TsumeGoProblem.fromFirestore(
        query.docs[problemIndex] as DocumentSnapshot<Map<String, dynamic>>,
      );
    } catch (e) {
      _logger.e('Error fetching tsume-go problem: $e');
      rethrow;
    }
  }

  /// Get tsume-go problem by ID
  Future<TsumeGoProblem?> getTsumeProblem(String problemId) async {
    try {
      _logger.i('Fetching tsume-go problem: $problemId');
      final doc = await _firestore
          .collection(tsumeGoProblemsCollection)
          .doc(problemId)
          .get();

      if (!doc.exists) {
        _logger.w('Tsume-go problem not found: $problemId');
        return null;
      }

      return TsumeGoProblem.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching tsume-go problem: $e');
      rethrow;
    }
  }

  /// Get tsume-go problems by difficulty
  Future<List<TsumeGoProblem>> getTsumeProblems(int difficulty, {int limit = 5}) async {
    try {
      _logger.i('Fetching tsume-go problems: difficulty=$difficulty');
      final query = await _firestore
          .collection(tsumeGoProblemsCollection)
          .where('difficulty', isEqualTo: difficulty)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => TsumeGoProblem.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching tsume-go problems: $e');
      rethrow;
    }
  }

  // ================== TSUME-GO LOG OPERATIONS ==================

  /// Save tsume-go attempt log
  Future<String> saveTsumeGoLog(UserTsumeGoLog log) async {
    try {
      _logger.i('Saving tsume-go log for user: ${log.uid}, problem: ${log.problemId}');
      final docRef = await _firestore
          .collection(userTsumeGoLogsCollection)
          .add(log.toFirestore());
      _logger.i('✅ Tsume-go log saved: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error saving tsume-go log: $e');
      rethrow;
    }
  }

  /// Get user's tsume-go solving streak
  Future<int> getTsumeGoStreak(String uid) async {
    try {
      _logger.i('Calculating tsume-go streak for user: $uid');
      final now = DateTime.now();
      var streak = 0;

      for (int i = 0; i < 365; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final query = await _firestore
            .collection(userTsumeGoLogsCollection)
            .where('uid', isEqualTo: uid)
            .where('isCorrect', isEqualTo: true)
            .where('solvedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('solvedAt', isLessThan: Timestamp.fromDate(dayEnd))
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          break; // Streak broken
        }

        streak++;
      }

      _logger.i('✅ Streak calculated: $streak days');
      return streak;
    } catch (e) {
      _logger.e('Error calculating streak: $e');
      rethrow;
    }
  }

  // ================== KIFU LIBRARY OPERATIONS ==================

  /// Get kifu (game record) by ID
  Future<KifuLibrary?> getKifu(String kifuId) async {
    try {
      _logger.i('Fetching kifu: $kifuId');
      final doc = await _firestore
          .collection(kifuLibraryCollection)
          .doc(kifuId)
          .get();

      if (!doc.exists) {
        _logger.w('Kifu not found: $kifuId');
        return null;
      }

      return KifuLibrary.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching kifu: $e');
      rethrow;
    }
  }

  /// Get copyright-free kifus (historical games)
  Future<List<KifuLibrary>> getCopyrightFreeKifus({int limit = 20}) async {
    try {
      _logger.i('Fetching copyright-free kifus');
      final query = await _firestore
          .collection(kifuLibraryCollection)
          .where('category', isEqualTo: 'copyright_free')
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => KifuLibrary.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching copyright-free kifus: $e');
      rethrow;
    }
  }

  /// Get user's own game kifus
  // ================== OBSERVATION LOG OPERATIONS ==================

  /// Save game observation log
  Future<String> saveObservationLog(ObservationLog log) async {
    try {
      _logger.i('Saving observation log: uid=${log.uid}, kifu=${log.kifuId}');
      final docRef = await _firestore
          .collection(observationLogsCollection)
          .add(log.toFirestore());
      _logger.i('✅ Observation log saved: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      _logger.e('Error saving observation log: $e');
      rethrow;
    }
  }

  /// Get user's observation history
  Future<List<ObservationLog>> getUserObservationLogs(String uid, {int limit = 10}) async {
    try {
      _logger.i('Fetching observation logs for user: $uid');
      final query = await _firestore
          .collection(observationLogsCollection)
          .where('uid', isEqualTo: uid)
          .orderBy('watchedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => ObservationLog.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching observation logs: $e');
      rethrow;
    }
  }

  // ================== BATCH OPERATIONS ==================

  /// Save game record AND increment games count in one atomic operation
  Future<String> saveGameRecordWithUserUpdate(GameRecord gameRecord, String uid) async {
    try {
      _logger.i('Saving game record and updating user stats');
      final batch = _firestore.batch();

      // Save game record
      final gameRef = _firestore.collection(gameRecordsCollection).doc();
      batch.set(gameRef, gameRecord.toFirestore());

      // Increment user's games count
      final userRef = _firestore.collection(usersCollection).doc(uid);
      batch.update(userRef, {'gamesPlayedCount': FieldValue.increment(1)});

      await batch.commit();
      _logger.i('✅ Batch operation completed: ${gameRef.id}');
      return gameRef.id;
    } catch (e) {
      _logger.e('Error in batch operation: $e');
      rethrow;
    }
  }
}

/// Custom exception for Firestore errors
class FirestoreServiceException implements Exception {
  final String message;
  final Object? originalException;

  FirestoreServiceException(this.message, [this.originalException]);

  @override
  String toString() =>
      'FirestoreServiceException: $message${originalException != null ? ' (caused by: $originalException)' : ''}';
}

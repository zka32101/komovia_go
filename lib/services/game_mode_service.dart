import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/sns_models.dart';

final _logger = Logger();

/// Service for managing game modes and game sessions
class GameModeService {
  final FirebaseFirestore _firestore;

  GameModeService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // ===== Game Mode Management =====

  /// Get all available game modes
  Future<List<GameMode>> getAllGameModes() async {
    try {
      final snapshot = await _firestore.collection('game_modes').get();
      return snapshot.docs
          .map((doc) => GameMode.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch game modes: $e');
      return [];
    }
  }

  /// Get active game modes only
  Future<List<GameMode>> getActiveGameModes() async {
    try {
      final snapshot = await _firestore
          .collection('game_modes')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => GameMode.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch active game modes: $e');
      return [];
    }
  }

  /// Get a specific game mode by ID
  Future<GameMode?> getGameMode(String modeId) async {
    try {
      final doc = await _firestore.collection('game_modes').doc(modeId).get();
      if (!doc.exists) return null;
      return GameMode.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      _logger.e('Failed to fetch game mode: $e');
      return null;
    }
  }

  /// Create a new game mode
  Future<GameMode?> createGameMode(GameMode mode) async {
    try {
      final docRef = await _firestore.collection('game_modes').add(
            mode.toJson()..remove('id'),
          );
      return GameMode.fromJson({...mode.toJson(), 'id': docRef.id});
    } catch (e) {
      _logger.e('Failed to create game mode: $e');
      return null;
    }
  }

  /// Update an existing game mode (admin only)
  Future<bool> updateGameMode(GameMode mode) async {
    try {
      await _firestore
          .collection('game_modes')
          .doc(mode.id)
          .update(mode.toJson()..remove('id'));
      return true;
    } catch (e) {
      _logger.e('Failed to update game mode: $e');
      return false;
    }
  }

  /// Delete a game mode (admin only)
  Future<bool> deleteGameMode(String modeId) async {
    try {
      await _firestore.collection('game_modes').doc(modeId).delete();
      return true;
    } catch (e) {
      _logger.e('Failed to delete game mode: $e');
      return false;
    }
  }

  // ===== Game Session Management =====

  /// Start a new game session
  Future<GameSession?> startGameSession({
    required GameMode gameMode,
    required String blackPlayerId,
    required String whitePlayerId,
  }) async {
    try {
      final sessionId = _firestore.collection('game_sessions').doc().id;

      final session = GameSession(
        sessionId: sessionId,
        gameId: _firestore.collection('games').doc().id,
        gameMode: gameMode,
        startedAt: DateTime.now(),
        blackPlayerId: blackPlayerId,
        whitePlayerId: whitePlayerId,
        timeRemainingBlack: gameMode.timeLimit,
        timeRemainingWhite: gameMode.timeLimit,
      );

      await _firestore
          .collection('game_sessions')
          .doc(sessionId)
          .set(session.toJson());

      // Also create the main game document
      await _firestore
          .collection('games')
          .doc(session.gameId)
          .set({
        'sessionId': sessionId,
        'modeId': gameMode.id,
        'blackPlayerId': blackPlayerId,
        'whitePlayerId': whitePlayerId,
        'startedAt': DateTime.now().toIso8601String(),
        'board': '', // Will be populated with game moves
        'moves': [],
      });

      return session;
    } catch (e) {
      _logger.e('Failed to start game session: $e');
      return null;
    }
  }

  /// Get active sessions for a player
  Future<List<GameSession>> getActiveSessionsForPlayer(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('game_sessions')
          .where('endedAt', isNull: true)
          .where('blackPlayerId', isEqualTo: userId)
          .get();

      final whiteSnapshot = await _firestore
          .collection('game_sessions')
          .where('endedAt', isNull: true)
          .where('whitePlayerId', isEqualTo: userId)
          .get();

      final allDocs = [...snapshot.docs, ...whiteSnapshot.docs];
      return allDocs
          .map((doc) => GameSession.fromJson({...doc.data(), 'sessionId': doc.id}))
          .toList();
    } catch (e) {
      _logger.e('Failed to fetch active sessions: $e');
      return [];
    }
  }

  /// End a game session
  Future<bool> endGameSession(String sessionId) async {
    try {
      await _firestore.collection('game_sessions').doc(sessionId).update({
        'endedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      _logger.e('Failed to end game session: $e');
      return false;
    }
  }

  /// Update remaining time for a player
  Future<bool> updateTimeRemaining({
    required String sessionId,
    required bool isBlackPlayer,
    required int secondsRemaining,
  }) async {
    try {
      final field = isBlackPlayer ? 'timeRemainingBlack' : 'timeRemainingWhite';
      await _firestore.collection('game_sessions').doc(sessionId).update({
        field: secondsRemaining,
      });
      return true;
    } catch (e) {
      _logger.e('Failed to update time remaining: $e');
      return false;
    }
  }

  // ===== Time Management =====

  /// Calculate remaining time based on start time and elapsed time
  int calculateRemainingTime({
    required int initialTime,
    required Duration elapsed,
  }) {
    return (initialTime - elapsed.inSeconds).clamp(0, initialTime);
  }

  /// Check if time has expired
  bool isTimeExpired({
    required int timeRemaining,
  }) {
    return timeRemaining <= 0;
  }

  // ===== Blitz Mode (5 minutes) =====

  /// Get or create Blitz game mode
  Future<GameMode> getBlitzMode() async {
    final mode = await getGameMode('blitz');
    if (mode != null) return mode;

    final newMode = GameMode(
      id: 'blitz',
      name: 'Blitz',
      description: '5分の高速対局モード。すばやい判断が必要です。',
      timeLimit: 300, // 5 minutes
      difficulty: 'standard',
      type: GameModeType.blitz,
      maxPlayers: 2,
      isActive: true,
    );

    return await createGameMode(newMode) ?? newMode;
  }

  // ===== Correspondence Mode (Turn-based) =====

  /// Get or create Correspondence game mode
  Future<GameMode> getCorrespondenceMode() async {
    final mode = await getGameMode('correspondence');
    if (mode != null) return mode;

    final newMode = GameMode(
      id: 'correspondence',
      name: 'Correspondence',
      description: 'ターンベース対局。じっくり考える時間があります。',
      timeLimit: 0, // No time limit per move
      difficulty: 'standard',
      type: GameModeType.correspondence,
      maxPlayers: 2,
      isActive: true,
    );

    return await createGameMode(newMode) ?? newMode;
  }

  // ===== Team Play Mode (2vs2) =====

  /// Get or create Team Play game mode
  Future<GameMode> getTeamPlayMode() async {
    final mode = await getGameMode('team_play');
    if (mode != null) return mode;

    final newMode = GameMode(
      id: 'team_play',
      name: 'Team Play',
      description: '2対2のチーム戦。協力プレイで勝利を目指します。',
      timeLimit: 600, // 10 minutes
      difficulty: 'standard',
      type: GameModeType.team,
      maxPlayers: 4,
      isActive: true,
    );

    return await createGameMode(newMode) ?? newMode;
  }

  // ===== Puzzle Rush Mode (Marathon) =====

  /// Get or create Puzzle Rush game mode
  Future<GameMode> getPuzzleRushMode() async {
    final mode = await getGameMode('puzzle_rush');
    if (mode != null) return mode;

    final newMode = GameMode(
      id: 'puzzle_rush',
      name: 'Puzzle Rush',
      description: 'タイムアタック詰碁。連続正解を目指します。',
      timeLimit: 1800, // 30 minutes total
      difficulty: 'variable',
      type: GameModeType.puzzleRush,
      maxPlayers: 1,
      isActive: true,
    );

    return await createGameMode(newMode) ?? newMode;
  }

  // ===== Handicap Mode =====

  /// Get or create Handicap game mode
  Future<GameMode> getHandicapMode() async {
    final mode = await getGameMode('handicap');
    if (mode != null) return mode;

    final newMode = GameMode(
      id: 'handicap',
      name: 'Handicap',
      description: 'ハンディキャップを使用した対局。レベル差を埋めます。',
      timeLimit: 600,
      difficulty: 'adaptive',
      type: GameModeType.handicap,
      maxPlayers: 2,
      isActive: true,
    );

    return await createGameMode(newMode) ?? newMode;
  }

  /// Set handicap stones for a game
  Future<bool> setHandicapStones({
    required String gameId,
    required int handicapCount,
  }) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'handicapStones': handicapCount,
      });
      return true;
    } catch (e) {
      _logger.e('Failed to set handicap: $e');
      return false;
    }
  }

  // ===== Statistics =====

  /// Get game mode statistics
  Future<Map<String, dynamic>> getGameModeStats(String modeId) async {
    try {
      final gamesSnapshot = await _firestore
          .collection('games')
          .where('modeId', isEqualTo: modeId)
          .get();

      final totalGames = gamesSnapshot.docs.length;
      final avgDuration = _calculateAvgDuration(gamesSnapshot.docs);

      return {
        'totalGames': totalGames,
        'avgDuration': avgDuration,
        'modeId': modeId,
      };
    } catch (e) {
      _logger.e('Failed to fetch mode stats: $e');
      return {};
    }
  }

  /// Calculate average game duration in seconds
  int _calculateAvgDuration(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return 0;

    int totalSeconds = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('startedAt') && data.containsKey('endedAt')) {
        // Parse timestamps and calculate duration
        totalSeconds += 300; // Placeholder
      }
    }
    return docs.isNotEmpty ? totalSeconds ~/ docs.length : 0;
  }
}

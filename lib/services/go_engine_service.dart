import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

// LEGACY / UNUSED: this file is the original Cloud Functions (GNU Go)
// engine wrapper, kept only for reference (see services/index.dart's own
// comment: AIMove/GameEndResult are hidden from the barrel export so the
// on-device Fuego versions in fuego_engine_service.dart are the ones
// actually resolved app-wide). GoEngineService has zero callers anywhere
// in lib/. If this is ever wired back up, note that its stone encoding
// below (-1=empty, 0=black, 1=white) is INCOMPATIBLE with the rest of the
// app's convention (BoardState/FuegoEngineService/GoRules all use
// 0=empty, 1=black, 2=white) — reusing it as-is would silently
// misinterpret every board passed through it.

/// Go board state representation for engine communication
class _EngineBoardState {
  final int boardSize; // 9, 13, or 19
  final List<List<int>> stones; // -1=empty, 0=black, 1=white
  final bool isPlayerBlack;

  _EngineBoardState({
    required this.boardSize,
    required this.stones,
    required this.isPlayerBlack,
  });

  /// Convert to SGF (Standard Game Format) for engine
  String toSgf() {
    final buffer = StringBuffer();
    buffer.write('(;GM[1]SZ[$boardSize]');

    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (stones[row][col] != -1) {
          final stoneType = stones[row][col] == 0 ? 'B' : 'W';
          buffer.write(';$stoneType[${_coordToSgf(col)},${_coordToSgf(row)}]');
        }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _coordToSgf(int coord) {
    // SGF uses letters: a-s for 19x19
    return String.fromCharCode(97 + coord);
  }

  @override
  String toString() =>
      '_EngineBoardState(size: ${boardSize}x$boardSize, playerBlack: $isPlayerBlack)';
}

/// AI move response
class AIMove {
  final int row;
  final int col;
  final double confidence; // 0.0-1.0
  final String? reasoning;

  AIMove({
    required this.row,
    required this.col,
    this.confidence = 0.8,
    this.reasoning,
  });

  factory AIMove.fromJson(Map<String, dynamic> json) {
    return AIMove(
      row: json['row'] as int,
      col: json['col'] as int,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      reasoning: json['reasoning'] as String?,
    );
  }

  @override
  String toString() => 'AIMove(row: $row, col: $col, confidence: $confidence)';
}

/// Game end result with scoring
class GameEndResult {
  final bool gameEnded;
  final double blackScore; // Chinese rules
  final double whiteScore;
  final String? winner; // 'black', 'white', 'draw'
  final String? scoringMethod; // 'chinese', 'japanese', etc.

  GameEndResult({
    required this.gameEnded,
    required this.blackScore,
    required this.whiteScore,
    this.winner,
    this.scoringMethod = 'chinese',
  });

  factory GameEndResult.fromJson(Map<String, dynamic> json) {
    return GameEndResult(
      gameEnded: json['gameEnded'] as bool? ?? false,
      blackScore: (json['blackScore'] as num?)?.toDouble() ?? 0.0,
      whiteScore: (json['whiteScore'] as num?)?.toDouble() ?? 0.0,
      winner: json['winner'] as String?,
      scoringMethod: json['scoringMethod'] as String? ?? 'chinese',
    );
  }

  @override
  String toString() =>
      'GameEndResult(ended: $gameEnded, black: $blackScore, white: $whiteScore, winner: $winner)';
}

/// Service for interacting with GNU Go engine via Cloud Functions
/// Uses Cloud Functions for cost efficiency & scalability
class GoEngineService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Logger _logger = Logger();

  // Configuration
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 2;
  static const String _regionDefault = 'us-central1';

  GoEngineService() {
    _logger.i('GoEngineService initialized. Region: $_regionDefault, Max retries: $_maxRetries');
  }

  /// Request AI move from GNU Go engine
  ///
  /// Parameters:
  /// - boardSize: Board size (9, 13, or 19)
  /// - stones: Board state (-1=empty, 0=black, 1=white)
  /// - isPlayerBlack: True if player is black
  /// - aiLevel: Difficulty 1-10 (1=easiest, 10=hardest)
  /// - movesCount: How many moves have been played (for time management)
  Future<AIMove> requestAiMove({
    required int boardSize,
    required List<List<int>> stones,
    required bool isPlayerBlack,
    required int aiLevel,
    int movesCount = 0,
  }) async {
    assert(aiLevel >= 1 && aiLevel <= 10, 'aiLevel must be 1-10');

    _logger.i('🎯 Requesting AI move: level=$aiLevel, boardSize=$boardSize, movesCount=$movesCount');

    final boardState = _EngineBoardState(
      boardSize: boardSize,
      stones: stones,
      isPlayerBlack: isPlayerBlack,
    );

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        _logger.d('📡 Attempt ${attempt + 1}/$_maxRetries: Calling requestAiMove function...');

        final callable = _functions.httpsCallable('requestAiMove');
        _logger.d('✓ Cloud Functions callable initialized');

        final payload = {
          'boardState': _encodeBoardState(boardState),
          'aiLevel': aiLevel,
          'movesCount': movesCount,
          'boardSize': boardState.boardSize,
          'timeout': _timeout.inSeconds,
        };
        _logger.d('📦 Payload prepared: ${payload.keys.toList()}');

        final result = await callable.call(payload).timeout(_timeout);

        _logger.i('✅ AI move received successfully: row=${result.data['row']}, col=${result.data['col']}, confidence=${result.data['confidence']}');
        return AIMove.fromJson(result.data as Map<String, dynamic>);
      } on FirebaseFunctionsException catch (e) {
        _logger.e('❌ Cloud Function error (attempt ${attempt + 1}/$_maxRetries)');
        _logger.e('  Code: ${e.code}');
        _logger.e('  Message: ${e.message}');
        _logger.e('  Details: ${e.details}');

        if (attempt < _maxRetries) {
          final delayMs = 1000 * (1 << attempt);
          _logger.i('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        rethrow;
      } on TimeoutException catch (e) {
        _logger.w('⏱️ Request timeout (attempt ${attempt + 1}/$_maxRetries): ${_timeout.inSeconds}s exceeded');

        if (attempt < _maxRetries) {
          final delayMs = 1000 * (1 << attempt);
          _logger.i('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        throw GoEngineException('AI move request timed out after $_maxRetries retries', e);
      } catch (e) {
        _logger.e('🔥 Unexpected error: ${e.runtimeType}');
        _logger.e('   Message: $e');
        rethrow;
      }
    }

    throw GoEngineException('Failed to get AI move after $_maxRetries retries');
  }

  /// Judge if game has ended and calculate score (Chinese rules)
  ///
  /// Parameters:
  /// - boardSize: Board size (9, 13, or 19)
  /// - stones: Board state (-1=empty, 0=black, 1=white)
  /// - isPlayerBlack: True if player is black
  /// - lastPlayerPassed: True if the last move was a pass
  ///
  /// Returns:
  /// - gameEnded: true if both players pass or board is full
  /// - blackScore/whiteScore: Points including territory (Chinese rules)
  /// - winner: 'black', 'white', or 'draw'
  Future<GameEndResult> judgeGameEnd({
    required int boardSize,
    required List<List<int>> stones,
    required bool isPlayerBlack,
    required bool lastPlayerPassed,
  }) async {
    _logger.i('🏁 Judging game end: boardSize=$boardSize, lastPassed=$lastPlayerPassed');

    final boardState = _EngineBoardState(
      boardSize: boardSize,
      stones: stones,
      isPlayerBlack: isPlayerBlack,
    );

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        _logger.d('📡 Attempt ${attempt + 1}/$_maxRetries: Calling judgeGameEnd function...');

        final callable = _functions.httpsCallable('judgeGameEnd');
        _logger.d('✓ Cloud Functions callable initialized');

        final payload = {
          'boardState': _encodeBoardState(boardState),
          'lastPlayerPassed': lastPlayerPassed,
          'boardSize': boardState.boardSize,
          'scoringMethod': 'chinese',
          'timeout': _timeout.inSeconds,
        };
        _logger.d('📦 Payload prepared for game judgment');

        final result = await callable.call(payload).timeout(_timeout);

        _logger.i('✅ Game judgment received: ended=${result.data['gameEnded']}, black=${result.data['blackScore']}, white=${result.data['whiteScore']}, winner=${result.data['winner']}');
        return GameEndResult.fromJson(result.data as Map<String, dynamic>);
      } on FirebaseFunctionsException catch (e) {
        _logger.e('❌ Cloud Function error (attempt ${attempt + 1}/$_maxRetries)');
        _logger.e('  Code: ${e.code}');
        _logger.e('  Message: ${e.message}');
        _logger.e('  Details: ${e.details}');

        if (attempt < _maxRetries) {
          final delayMs = 1000 * (1 << attempt);
          _logger.i('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        rethrow;
      } on TimeoutException catch (e) {
        _logger.w('⏱️ Request timeout (attempt ${attempt + 1}/$_maxRetries): ${_timeout.inSeconds}s exceeded');

        if (attempt < _maxRetries) {
          final delayMs = 1000 * (1 << attempt);
          _logger.i('⏳ Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        throw GoEngineException('Game judgment timed out after $_maxRetries retries', e);
      } catch (e) {
        _logger.e('🔥 Unexpected error: ${e.runtimeType}');
        _logger.e('   Message: $e');
        rethrow;
      }
    }

    throw GoEngineException('Failed to judge game end after $_maxRetries retries');
  }

  /// Validate a move (check if legal)
  ///
  /// Useful for quick client-side validation before sending to engine
  bool validateMove({
    required int boardSize,
    required List<List<int>> stones,
    required int row,
    required int col,
  }) {
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
      return false;
    }

    // Position must be empty
    if (stones[row][col] != -1) {
      return false;
    }

    return true;
  }

  /// Encode board state for Cloud Function transmission
  Map<String, dynamic> _encodeBoardState(_EngineBoardState state) {
    return {
      'boardSize': state.boardSize,
      'stones': state.stones.map((row) => row.toList()).toList(),
      'isPlayerBlack': state.isPlayerBlack,
    };
  }
}

/// Custom exception for Go engine errors
class GoEngineException implements Exception {
  final String message;
  final Object? originalException;

  GoEngineException(this.message, [this.originalException]);

  @override
  String toString() => 'GoEngineException: $message${originalException != null ? ' (caused by: $originalException)' : ''}';
}

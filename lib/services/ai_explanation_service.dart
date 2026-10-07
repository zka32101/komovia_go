import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

/// Move explanation/commentary
class MoveExplanation {
  final int moveNumber;
  final int row;
  final int col;
  final String playerColor; // 'black' or 'white'
  final String basicExplanation; // 1-2 sentences
  final String? advancedExplanation; // More detailed analysis
  final String? strategicNote; // Long-term strategic value
  final double confidenceLevel; // 0.0-1.0

  MoveExplanation({
    required this.moveNumber,
    required this.row,
    required this.col,
    required this.playerColor,
    required this.basicExplanation,
    this.advancedExplanation,
    this.strategicNote,
    this.confidenceLevel = 0.8,
  });

  factory MoveExplanation.fromJson(Map<String, dynamic> json) {
    return MoveExplanation(
      moveNumber: json['moveNumber'] as int,
      row: json['row'] as int,
      col: json['col'] as int,
      playerColor: json['playerColor'] as String,
      basicExplanation: json['basicExplanation'] as String,
      advancedExplanation: json['advancedExplanation'] as String?,
      strategicNote: json['strategicNote'] as String?,
      confidenceLevel: (json['confidenceLevel'] as num?)?.toDouble() ?? 0.8,
    );
  }

  @override
  String toString() =>
      'MoveExplanation(move: $moveNumber, $playerColor at [$row,$col]): $basicExplanation';
}

/// Game analysis result with move-by-move explanations
class GameAnalysis {
  final String kifuId; // Reference to the game
  final List<MoveExplanation> moves;
  final String overallTheme; // General description of the game
  final String keyTurningPoints; // When the advantage shifted
  final String conclusion; // Final assessment

  GameAnalysis({
    required this.kifuId,
    required this.moves,
    required this.overallTheme,
    required this.keyTurningPoints,
    required this.conclusion,
  });

  factory GameAnalysis.fromJson(Map<String, dynamic> json) {
    return GameAnalysis(
      kifuId: json['kifuId'] as String,
      moves: (json['moves'] as List<dynamic>)
          .map((m) => MoveExplanation.fromJson(m as Map<String, dynamic>))
          .toList(),
      overallTheme: json['overallTheme'] as String,
      keyTurningPoints: json['keyTurningPoints'] as String,
      conclusion: json['conclusion'] as String,
    );
  }

  @override
  String toString() =>
      'GameAnalysis(game: $kifuId, ${moves.length} moves explained)';
}

/// Service for generating AI explanations of Go moves and games
/// Uses Cloud Functions for computational efficiency
/// NOTE: In production, this would use petit_ai or another AI service
class AIExplanationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Logger _logger = Logger();

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;
  static const String _regionDefault = 'us-central1';

  /// Generate explanation for a single move
  ///
  /// Parameters:
  /// - sgfData: Game state up to this move in SGF format
  /// - moveNumber: Which move number this is (1-indexed)
  /// - moveRow/moveCol: Coordinates of the move
  /// - playerColor: 'black' or 'white'
  /// - explanationLevel: 'basic' (1-2 sentences) or 'advanced' (detailed analysis)
  Future<MoveExplanation> generateMoveExplanation({
    required String sgfData,
    required int moveNumber,
    required int moveRow,
    required int moveCol,
    required String playerColor,
    String explanationLevel = 'basic',
  }) async {
    assert(playerColor == 'black' || playerColor == 'white', 'playerColor must be black or white');
    assert(explanationLevel == 'basic' || explanationLevel == 'advanced',
        'explanationLevel must be basic or advanced');

    _logger.i('Generating move explanation: move $moveNumber ($playerColor at [$moveRow,$moveCol])');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final callable = _functions
            .httpsCallable('generateMoveExplanation');

        final result = await callable.call({
          'sgfData': sgfData,
          'moveNumber': moveNumber,
          'moveRow': moveRow,
          'moveCol': moveCol,
          'playerColor': playerColor,
          'explanationLevel': explanationLevel,
          'language': 'ja', // Japanese explanations for adult audience
          'timeout': _timeout.inSeconds,
        }).timeout(_timeout);

        _logger.i('✅ Move explanation generated');
        return MoveExplanation.fromJson(result.data as Map<String, dynamic>);
      } on FirebaseFunctionsException catch (e) {
        _logger.w('❌ Cloud Function error (attempt ${attempt + 1}/$_maxRetries): ${e.message}');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000 * (1 << attempt)));
          continue;
        }

        rethrow;
      } on TimeoutException catch (e) {
        _logger.w('⏱️ Request timeout (attempt ${attempt + 1}/$_maxRetries): $e');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000 * (1 << attempt)));
          continue;
        }

        throw AIExplanationException('Move explanation timed out', e);
      } catch (e) {
        _logger.e('🔥 Unexpected error: $e');
        rethrow;
      }
    }

    throw AIExplanationException('Failed to generate move explanation after $_maxRetries retries');
  }

  /// Generate comprehensive game analysis with move-by-move explanations
  ///
  /// Parameters:
  /// - sgfData: Complete game in SGF format
  /// - kifuId: Reference ID for caching/storage
  /// - focusMoves: Optional list of move numbers to focus on (for premium users)
  ///
  /// Note: This is computationally expensive and should be done asynchronously
  /// Consider caching results in Firestore for frequently viewed games
  Future<GameAnalysis> generateGameAnalysis({
    required String sgfData,
    required String kifuId,
    List<int>? focusMoves,
  }) async {
    _logger.i('Generating game analysis for kifu: $kifuId');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final callable = _functions
            .httpsCallable('generateGameAnalysis');

        final result = await callable.call({
          'sgfData': sgfData,
          'kifuId': kifuId,
          'focusMoves': focusMoves,
          'language': 'ja',
          'timeout': _timeout.inSeconds,
        }).timeout(_timeout);

        _logger.i('✅ Game analysis generated');
        return GameAnalysis.fromJson(result.data as Map<String, dynamic>);
      } on FirebaseFunctionsException catch (e) {
        _logger.w('❌ Cloud Function error (attempt ${attempt + 1}/$_maxRetries): ${e.message}');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 2000 * (1 << attempt))); // Longer backoff
          continue;
        }

        rethrow;
      } on TimeoutException catch (e) {
        _logger.w('⏱️ Request timeout (attempt ${attempt + 1}/$_maxRetries): $e');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 2000 * (1 << attempt)));
          continue;
        }

        throw AIExplanationException('Game analysis timed out', e);
      } catch (e) {
        _logger.e('🔥 Unexpected error: $e');
        rethrow;
      }
    }

    throw AIExplanationException('Failed to generate game analysis after $_maxRetries retries');
  }

  /// Generate quick move summary (1-2 sentences, fast)
  ///
  /// Used for real-time move explanations during gameplay
  /// Much faster than full analysis
  Future<String> generateQuickMoveComment({
    required String sgfData,
    required int moveNumber,
    required int moveRow,
    required int moveCol,
  }) async {
    _logger.i('Generating quick move comment: move $moveNumber');

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final callable = _functions
            .httpsCallable('generateQuickMoveComment');

        final result = await callable.call({
          'sgfData': sgfData,
          'moveNumber': moveNumber,
          'moveRow': moveRow,
          'moveCol': moveCol,
          'language': 'ja',
          'timeout': 5, // Very short timeout for quick response
        }).timeout(const Duration(seconds: 5));

        _logger.i('✅ Quick comment generated');
        return result.data as String;
      } on FirebaseFunctionsException catch (e) {
        _logger.w('❌ Cloud Function error (attempt ${attempt + 1}/$_maxRetries): ${e.message}');

        if (attempt < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
          continue;
        }

        // Return fallback message on error
        _logger.w('Using fallback message');
        return '着手 ($moveRow, $moveCol)';
      } catch (e) {
        _logger.e('🔥 Unexpected error: $e');
        return '着手 ($moveRow, $moveCol)';
      }
    }

    return '着手 ($moveRow, $moveCol)';
  }

  /// Cache analysis in Firestore for later retrieval
  ///
  /// Call after analysis is generated to avoid recomputing
  Future<void> cacheGameAnalysis({
    required String kifuId,
    required GameAnalysis analysis,
  }) async {
    try {
      _logger.i('Caching game analysis for kifu: $kifuId');
      // Implementation would store in Firestore
      // For now, this is a placeholder for future implementation
      _logger.i('✅ Analysis cached (placeholder)');
    } catch (e) {
      _logger.e('Error caching analysis: $e');
      // Non-fatal error - analysis was generated successfully
    }
  }
}

/// Custom exception for AI Explanation errors
class AIExplanationException implements Exception {
  final String message;
  final Object? originalException;

  AIExplanationException(this.message, [this.originalException]);

  @override
  String toString() =>
      'AIExplanationException: $message${originalException != null ? ' (caused by: $originalException)' : ''}';
}

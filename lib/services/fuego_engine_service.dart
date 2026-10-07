import 'package:logger/logger.dart';
import 'package:komovia_go/native/fuego_bindings.dart';
import 'package:komovia_go/services/dart_go_engine.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';
import 'dart:math' as math;

/// AI move response (Fuego version)
class AIMove {
  final int row;
  final int col;
  final double confidence;
  final String? reasoning;

  AIMove({
    required this.row,
    required this.col,
    this.confidence = 0.8,
    this.reasoning,
  });

  /// A negative coordinate is the pass signal from the native engine.
  bool get isPass => row < 0 || col < 0;

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

/// Game end result
class GameEndResult {
  final bool gameEnded;
  final double blackScore;
  final double whiteScore;
  final String? winner;
  final String? scoringMethod;
  /// Number of stones Fuego's safety solver determined were dead and
  /// removed before scoring (0 if dead-stone detection wasn't available).
  final int deadStoneCount;

  GameEndResult({
    required this.gameEnded,
    required this.blackScore,
    required this.whiteScore,
    this.winner,
    this.scoringMethod = 'chinese',
    this.deadStoneCount = 0,
  });

  factory GameEndResult.fromJson(Map<String, dynamic> json) {
    return GameEndResult(
      gameEnded: json['gameEnded'] as bool? ?? false,
      blackScore: (json['blackScore'] as num?)?.toDouble() ?? 0.0,
      whiteScore: (json['whiteScore'] as num?)?.toDouble() ?? 0.0,
      winner: json['winner'] as String?,
      scoringMethod: json['scoringMethod'] as String? ?? 'chinese',
      deadStoneCount: (json['deadStoneCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'GameEndResult(ended: $gameEnded, black: $blackScore, white: $whiteScore, winner: $winner, deadStones: $deadStoneCount)';
}

/// Fuego Go エンジン (On-device, lightweight)
///
/// 特徴:
/// - ローカルで実行 (Firebase 不要)
/// - 高速 (1秒以内)
/// - 9x9 最適化
/// - オフライン対応
class FuegoEngineService {
  /// Null when the native Fuego library is not bundled; the built-in Dart
  /// engine (DartGoEngine) is used for move generation in that case.
  FuegoNative? _fuego;
  final Logger _logger = Logger();

  FuegoEngineService() {
    _initialize();
  }

  void _initialize() {
    try {
      final native = FuegoNative();
      final result = native.initialize();
      _fuego = native;
      _logger.i('✅ Fuego エンジン初期化成功 (code: $result)');
    } catch (e) {
      _fuego = null;
      _logger.w('⚠️ Fuego ネイティブ未搭載のため内蔵 Dart エンジンを使用します: $e');
    }
  }

  /// AI の手を取得
  ///
  /// Parameters:
  /// - boardSize: ボードサイズ (9, 13, 19)
  /// - stones: ボード状態 (0=empty, 1=black, 2=white)
  /// - isPlayerBlack: プレイヤーが黒か
  /// - aiLevel: AI レベル (1-10)
  /// - movesCount: 既に打たれた手数
  Future<AIMove> requestAiMove({
    required int boardSize,
    required List<List<int>> stones,
    required bool isPlayerBlack,
    required int aiLevel,
    int movesCount = 0,
    int? koRow,
    int? koCol,
  }) async {
    assert(aiLevel >= 1 && aiLevel <= 10, 'aiLevel must be 1-10');

    _logger.i('🎯 AI の手を要求 (level=$aiLevel, size=$boardSize, native=${_fuego != null})');

    final fuego = _fuego;
    if (fuego != null) {
      try {
        // ボード状態を 1D 配列に変換
        final boardFlat = <int>[];
        for (int row = 0; row < boardSize; row++) {
          for (int col = 0; col < boardSize; col++) {
            boardFlat.add(stones[row][col]);
          }
        }

        final moveId = fuego.getMove(boardFlat, boardSize, aiLevel);
        final (row, col) = fuego.getMoveCoords(moveId);

        _logger.i('✅ Fuego 応答: row=$row, col=$col');

        return AIMove(
          row: row,
          col: col,
          confidence: 0.85,
          reasoning: 'Fuego evaluation',
        );
      } catch (e) {
        _logger.w('⚠️ Fuego エラー、内蔵 Dart エンジンにフォールバック: $e');
      }
    }

    final move = await DartGoEngine.chooseMove(
      stones: stones,
      boardSize: boardSize,
      player: isPlayerBlack ? 2 : 1,
      aiLevel: aiLevel,
      koRow: koRow,
      koCol: koCol,
    );

    if (move == null) {
      _logger.i('✅ Dart エンジン: パス');
      return AIMove(row: -1, col: -1, confidence: 0.5, reasoning: 'Dart engine pass');
    }

    _logger.i('✅ Dart エンジン応答: row=${move.$1}, col=${move.$2}');
    return AIMove(
      row: move.$1,
      col: move.$2,
      confidence: 0.6,
      reasoning: 'Dart Monte Carlo engine (level $aiLevel)',
    );
  }

  /// ゲーム終局を判定（中国ルール: 石数 + 地）
  ///
  /// Fuego の安全性読み（GoSafetySolver 相当）が使えるネイティブビルド
  /// では、死石を自動判定して盤面から除外してから採点する。未対応の
  /// ビルドでは全ての石を生きているものとして数える（フォールバック）。
  /// 自動判定が使えないビルドでも正しく採点したい場合は、
  /// [suggestDeadStones]/[scoreWithDeadStones] を使い、手動の死石確認
  /// ステップ（DeadStoneMarkingScreen 等）を挟むこと。
  Future<GameEndResult> judgeGameEnd({
    required int boardSize,
    required List<List<int>> stones,
    required bool isPlayerBlack,
    required bool lastPlayerPassed,
  }) async {
    _logger.i('🏁 ゲーム終了判定: lastPassed=$lastPlayerPassed');

    try {
      final deadPoints = suggestDeadStones(stones: stones, boardSize: boardSize);
      if (deadPoints.isNotEmpty) {
        _logger.i('☠️ 死石 ${deadPoints.length} 個を除外して採点');
      }
      return scoreWithDeadStones(
        stones: stones,
        boardSize: boardSize,
        deadPoints: deadPoints.toSet(),
      );
    } catch (e) {
      _logger.e('🔥 終局判定エラー: $e');
      rethrow;
    }
  }

  /// [deadPoints]（空=死石なし）を盤面から除外した上で中国ルールの地合を
  /// 採点する。ネイティブの自動判定・手動マーキングのどちらの結果も
  /// このメソッドで最終スコアに変換できる。
  GameEndResult scoreWithDeadStones({
    required int boardSize,
    required List<List<int>> stones,
    required Set<(int, int)> deadPoints,
  }) {
    final scoringStones = GoScoring.withDeadStonesRemoved(stones, deadPoints);
    final score = GoScoring.computeAreaScore(scoringStones, boardSize);

    _logger.i('📊 終局スコア: 黒=${score.blackScore} 白=${score.whiteScore}');

    final winner = score.blackScore > score.whiteScore
        ? 'black'
        : score.whiteScore > score.blackScore
            ? 'white'
            : 'draw';

    return GameEndResult(
      gameEnded: true,
      blackScore: score.blackScore,
      whiteScore: score.whiteScore,
      winner: winner,
      scoringMethod: 'chinese',
      deadStoneCount: deadPoints.length,
    );
  }

  /// Fuego の安全性読みで死石を判定する。
  /// ネイティブ側が fuego_get_dead_stones を実装していない場合は
  /// 空リストを返す（＝全石生存扱いにフォールバック。手動マーキング
  /// 画面の初期提案としても使われるため公開メソッドにしている）。
  List<(int, int)> suggestDeadStones({required List<List<int>> stones, required int boardSize}) {
    final fuego = _fuego;
    if (fuego == null || !fuego.supportsDeadStoneDetection) {
      return const [];
    }

    try {
      final boardFlat = <int>[];
      for (int row = 0; row < boardSize; row++) {
        for (int col = 0; col < boardSize; col++) {
          boardFlat.add(stones[row][col]);
        }
      }

      final deadFlags = fuego.getDeadStones(boardFlat, boardSize);
      final deadPoints = <(int, int)>[];
      for (int row = 0; row < boardSize; row++) {
        for (int col = 0; col < boardSize; col++) {
          if (deadFlags[row * boardSize + col] == 1) {
            deadPoints.add((row, col));
          }
        }
      }
      return deadPoints;
    } catch (e) {
      _logger.w('⚠️ 死石判定に失敗、全石生存扱いにフォールバック: $e');
      return const [];
    }
  }

  /// 着手が合法か検証（石取り・自殺手禁止・コウを考慮）
  bool validateMove({
    required int boardSize,
    required List<List<int>> stones,
    required int row,
    required int col,
    required int player,
    int? koRow,
    int? koCol,
  }) {
    return GoRules.isLegalMove(
      stones: stones,
      boardSize: boardSize,
      row: row,
      col: col,
      player: player,
      koRow: koRow,
      koCol: koCol,
    );
  }

  /// 盤面の形勢を評価 (簡易版)
  ///
  /// 石数と領地推定に基づいて評価を計算
  /// 中国ルール対応 (コミ 3.75)
  Future<PositionEvaluation> evaluatePosition({
    required List<List<int>> stones,
    required int boardSize,
  }) async {
    _logger.i('📊 形勢評価開始 (boardSize=$boardSize)');

    try {
      final score = GoScoring.computeAreaScore(stones, boardSize);
      final blackScore = score.blackScore;
      final whiteScore = score.whiteScore;
      final scoreDiff = blackScore - whiteScore;

      // 評価テキスト
      String assessment;
      if (scoreDiff > 10) {
        assessment = '黒が圧倒的に優勢';
      } else if (scoreDiff > 5) {
        assessment = '黒が優勢';
      } else if (scoreDiff > 1) {
        assessment = '黒がやや優勢';
      } else if (scoreDiff < -10) {
        assessment = '白が圧倒的に優勢';
      } else if (scoreDiff < -5) {
        assessment = '白が優勢';
      } else if (scoreDiff < -1) {
        assessment = '白がやや優勢';
      } else {
        assessment = '互角';
      }

      // 勝率推定（シグモイド関数使用）
      final blackWinProbability = 1.0 / (1.0 + math.exp(-scoreDiff / 10.0));

      _logger.i(
        '✅ 形勢評価: $assessment (スコア差: $scoreDiff, 黒勝率: ${(blackWinProbability * 100).toStringAsFixed(1)}%)',
      );

      return PositionEvaluation(
        blackScore: blackScore,
        whiteScore: whiteScore,
        scoreDiff: scoreDiff,
        assessment: assessment,
        blackWinProbability: blackWinProbability,
      );
    } catch (e) {
      _logger.e('🔥 形勢評価エラー: $e');
      rethrow;
    }
  }

  /// エンジンをクリーンアップ
  void dispose() {
    try {
      _fuego?.dispose();
      _logger.i('✅ Fuego エンジン クリーンアップ完了');
    } catch (e) {
      _logger.e('❌ クリーンアップエラー: $e');
    }
  }
}

/// Board position evaluation result
class PositionEvaluation {
  final double blackScore;
  final double whiteScore;
  final double scoreDiff;
  final String assessment;
  final double blackWinProbability;

  PositionEvaluation({
    required this.blackScore,
    required this.whiteScore,
    required this.scoreDiff,
    required this.assessment,
    required this.blackWinProbability,
  });

  @override
  String toString() =>
      'Evaluation(black: $blackScore, white: $whiteScore, diff: $scoreDiff, black_win: $blackWinProbability)';
}

/// Custom exception for Fuego engine errors
class FuegoException implements Exception {
  final String message;
  final Object? originalException;

  FuegoException(this.message, [this.originalException]);

  @override
  String toString() =>
      'FuegoException: $message${originalException != null ? ' (caused by: $originalException)' : ''}';
}

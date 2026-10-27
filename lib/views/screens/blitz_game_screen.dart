import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';
import 'package:komovia_go/utils/ai_rating.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/utils/sgf_parser.dart';
import 'package:komovia_go/views/widgets/go_board_grid_painter.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';

final _logger = Logger();

/// 盤面の線の色（dead_stone_marking_screen.dartと同じ木目調パレット）。
const Color _woodLine = Color(0xB83A2711);

/// BlitzGameScreen - 5分急速戦
///
/// 以前は盤面も着手判定も無く、`_selectedRow`/`_selectedCol`が常に
/// `-1,-1`のまま、終局処理が`result = 'white_win'`固定という実質
/// プレースホルダーだった。AIGameScreenと同じ`GoRules`(純粋関数の
/// 着手検証・捕獲ロジック)/`GoScoring`(中国式地合い計算)を使い、
/// 実際にタップで着手できる盤面・AI対局(FuegoEngineService)・
/// 実スコアに基づく終局判定に差し替えた。
///
/// 対人戦(`opponentUid`が指定された場合)は、Firestoreを介した
/// リアルタイム同期の仕組みがBlitzには存在しないため、同一デバイス上で
/// 交互に着手する「対面対局」として実装している(PvpGameScreenが持つ
/// ようなFirestoreトランザクション同期は本PRの範囲外)。
///
/// Features:
/// - Real-time countdown timer (5 minutes)
/// - 実際にタップで石を置ける盤面(GoRules/GoScoring使用)
/// - AI対局(FuegoEngineService、aiLevel指定時)/対人戦(ローカル対面)
/// - 終局時の実スコア判定・レーティング反映(AI対局時)
/// - 実対局内容からのSGF生成
class BlitzGameScreen extends ConsumerStatefulWidget {
  final String uid;
  final String? opponentUid;
  final String? aiLevel;
  final int boardSize;

  const BlitzGameScreen({
    Key? key,
    required this.uid,
    this.opponentUid,
    this.aiLevel,
    this.boardSize = 19,
  }) : super(key: key);

  @override
  ConsumerState<BlitzGameScreen> createState() => _BlitzGameScreenState();
}

class _BlitzGameScreenState extends ConsumerState<BlitzGameScreen> {
  int _timeRemainingSeconds = 5 * 60;
  Timer? _countdownTimer;

  BlitzGameRecord? _game;
  List<List<int>>? _stones;
  bool _isBlackTurn = true;
  int _capturedBlack = 0;
  int _capturedWhite = 0;
  int? _lastMoveRow;
  int? _lastMoveCol;
  int? _koRow;
  int? _koCol;
  int _consecutivePasses = 0;
  final List<({int row, int col, String player})> _moves = [];

  bool _isAiThinking = false;
  bool _gameEnded = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _logger.i(
      'BlitzGameScreen initialized - '
      'uid: ${widget.uid}, boardSize: ${widget.boardSize}',
    );
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _timeRemainingSeconds--;
      });
      if (_timeRemainingSeconds > 0) {
        _startTimer();
      } else {
        _logger.i('Blitz game time expired');
        _handleGameTimeout();
      }
    });
  }

  /// 以前はタイムアウトすると対局記録を一切保存せずに画面を閉じて
  /// いた(終局処理がそもそも呼ばれない)。時間切れも「その時点の盤面
  /// で終局」として扱い、他の終局経路と同じ`_endGame`に合流させる。
  void _handleGameTimeout() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.timeExpiredMessage)),
    );
    if (!_gameEnded && _game != null) {
      _endGame(context, l10n);
    }
  }

  bool get _isHumanTurn {
    // whitePlayer は常に widget.uid (BlitzGameService.startBlitzGame参照)。
    // AI対局時はAIが黒番で先手。対人戦(ローカル対面)では両者ともタップで
    // 着手するため常にtrue。
    if (widget.aiLevel == null) return true;
    return !_isBlackTurn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final gameAsync = ref.watch(
      startBlitzGameProvider(
        (
          uid: widget.uid,
          boardSize: widget.boardSize,
          aiLevel: widget.aiLevel,
          opponentUid: widget.opponentUid ?? 'ai',
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.blitzGameTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: gameAsync.when(
        data: (game) {
          if (!_initialized) {
            _initialized = true;
            _game = game;
            _stones = List.generate(
              game.boardSize,
              (_) => List.filled(game.boardSize, 0),
            );
            // AI対局はAIが黒番で先手。初期化直後に1手目を打たせる。
            if (widget.aiLevel != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _triggerAiMove(l10n);
              });
            }
          }
          return _buildGameBoard(context, l10n, game);
        },
        loading: () => _buildLoadingState(context, l10n),
        error: (error, stackTrace) =>
            _buildErrorState(context, l10n, error.toString()),
      ),
    );
  }

  Widget _buildGameBoard(
    BuildContext context,
    AppLocalizations l10n,
    BlitzGameRecord game,
  ) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            color: AppColors.sumi,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoColumn(
                  l10n.timeRemainingLabel,
                  _formatTime(_timeRemainingSeconds),
                  valueColor:
                      _timeRemainingSeconds < 30 ? Colors.red : AppColors.washi,
                ),
                _buildInfoColumn(
                  l10n.aiLevelLabel,
                  widget.aiLevel ?? 'N/A',
                ),
                _buildInfoColumn(
                  l10n.boardSizeLabel,
                  '${game.boardSize}×${game.boardSize}',
                ),
                _buildInfoColumn(
                  '捕獲',
                  '黒$_capturedWhite / 白$_capturedBlack',
                ),
              ],
            ),
          ),
          if (_isAiThinking)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aiThinkingPhrase1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildBoard(context),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _gameEnded || _isAiThinking || !_isHumanTurn
                        ? null
                        : () => _handlePass(context, l10n),
                    icon: const Icon(Icons.skip_next),
                    label: Text(l10n.passButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _gameEnded
                        ? null
                        : () => _handleResign(context, l10n),
                    icon: const Icon(Icons.flag),
                    label: Text(l10n.resignButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: valueColor ?? AppColors.washi,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(BuildContext context) {
    final stones = _stones;
    if (stones == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardPixelSize = constraints.biggest.shortestSide;
        final geometry = GoBoardGeometry(
          size: boardPixelSize,
          boardSize: widget.boardSize,
        );

        return GestureDetector(
          onTapDown: (details) {
            if (_gameEnded || _isAiThinking || !_isHumanTurn) return;
            final nearest = geometry.nearestIntersection(details.localPosition);
            _handlePlaceStone(context, nearest.row, nearest.col);
          },
          child: Container(
            width: boardPixelSize,
            height: boardPixelSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFC79A5C),
                  Color(0xFFA87C45),
                  Color(0xFFC79A5C),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sumi.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                CustomPaint(
                  painter: GoBoardGridPainter(
                    boardSize: widget.boardSize,
                    lineColor: _woodLine,
                    starPointColor: _woodLine,
                  ),
                  size: Size(boardPixelSize, boardPixelSize),
                ),
                ..._buildStones(geometry, stones),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildStones(GoBoardGeometry geometry, List<List<int>> stones) {
    final stoneWidgets = <Widget>[];
    final stoneRadius = geometry.pitch * 0.4;

    for (int row = 0; row < geometry.boardSize; row++) {
      for (int col = 0; col < geometry.boardSize; col++) {
        final stone = stones[row][col];
        if (stone == 0) continue;

        final center = geometry.intersectionOffset(row, col);
        final isLastMove = row == _lastMoveRow && col == _lastMoveCol;

        stoneWidgets.add(
          Positioned(
            left: center.dx - stoneRadius,
            top: center.dy - stoneRadius,
            child: GoStone(
              radius: stoneRadius,
              isBlack: stone == 1,
              child: isLastMove
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: stone == 1 ? AppColors.washi : AppColors.shu,
                          width: 1.5,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      }
    }

    return stoneWidgets;
  }

  void _handlePlaceStone(BuildContext context, int row, int col) {
    final stones = _stones;
    if (stones == null) return;

    final player = _isBlackTurn ? 1 : 2;
    final result = GoRules.applyMove(
      stones: stones,
      boardSize: widget.boardSize,
      row: row,
      col: col,
      player: player,
      koRow: _koRow,
      koCol: _koCol,
    );

    if (result == null) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() {
      _stones = result.stones;
      if (player == 1) {
        _capturedWhite += result.capturedCount;
      } else {
        _capturedBlack += result.capturedCount;
      }
      _lastMoveRow = row;
      _lastMoveCol = col;
      _koRow = result.koRow;
      _koCol = result.koCol;
      _isBlackTurn = !_isBlackTurn;
      _consecutivePasses = 0;
      _moves.add((row: row, col: col, player: player == 1 ? 'black' : 'white'));
    });

    _recordMove(row: row, col: col, player: player);

    if (widget.aiLevel != null && _isBlackTurn) {
      final l10n = AppLocalizations.of(context)!;
      _triggerAiMove(l10n);
    }
  }

  void _handlePass(BuildContext context, AppLocalizations l10n) {
    setState(() {
      _lastMoveRow = null;
      _lastMoveCol = null;
      _koRow = null;
      _koCol = null;
      _consecutivePasses++;
      _moves.add(
        (row: -1, col: -1, player: _isBlackTurn ? 'black' : 'white'),
      );
      _isBlackTurn = !_isBlackTurn;
    });

    if (_consecutivePasses >= 2) {
      _endGame(context, l10n);
      return;
    }

    if (widget.aiLevel != null && _isBlackTurn) {
      _triggerAiMove(l10n);
    }
  }

  void _handleResign(BuildContext context, AppLocalizations l10n) {
    // 投了した側は常に自分(white側、BlitzGameService.startBlitzGame参照)
    // なので、必ず黒(AI/相手)の勝ちとして終局する。
    _endGame(context, l10n, forcedWinnerColor: 'black');
  }

  void _recordMove({required int row, required int col, required int player}) {
    final game = _game;
    if (game == null) return;
    final move = '${String.fromCharCode(65 + col)}${row + 1}';
    ref.read(
      addBlitzMoveProvider(
        (
          gameId: game.id,
          move: move,
          playerColor: player == 1 ? 'black' : 'white',
        ),
      ),
    );
  }

  Future<void> _triggerAiMove(AppLocalizations l10n) async {
    final stones = _stones;
    final aiLevelStr = widget.aiLevel;
    if (stones == null || aiLevelStr == null || !mounted) return;

    final aiLevel = int.tryParse(aiLevelStr) ?? 5;
    setState(() => _isAiThinking = true);

    try {
      final aiMove = await ref.read(aiEngineServiceProvider).requestAiMove(
            boardSize: widget.boardSize,
            stones: stones,
            isPlayerBlack: true,
            aiLevel: aiLevel.clamp(1, 10),
            movesCount: _moves.length,
            koRow: _koRow,
            koCol: _koCol,
          );

      if (!mounted) return;

      if (aiMove.isPass) {
        setState(() {
          _isAiThinking = false;
          _lastMoveRow = null;
          _lastMoveCol = null;
          _koRow = null;
          _koCol = null;
          _consecutivePasses++;
          _moves.add((row: -1, col: -1, player: 'black'));
          _isBlackTurn = false;
        });
        if (_consecutivePasses >= 2 && mounted) {
          _endGame(context, l10n);
        }
        return;
      }

      final result = GoRules.applyMove(
        stones: stones,
        boardSize: widget.boardSize,
        row: aiMove.row,
        col: aiMove.col,
        player: 1,
        koRow: _koRow,
        koCol: _koCol,
      );

      if (result == null) {
        // AIが非合法手を返した場合はパス扱いにして先に進める。
        setState(() {
          _isAiThinking = false;
          _consecutivePasses++;
          _isBlackTurn = false;
        });
        return;
      }

      setState(() {
        _stones = result.stones;
        _capturedWhite += result.capturedCount;
        _lastMoveRow = aiMove.row;
        _lastMoveCol = aiMove.col;
        _koRow = result.koRow;
        _koCol = result.koCol;
        _isBlackTurn = false;
        _consecutivePasses = 0;
        _moves.add((row: aiMove.row, col: aiMove.col, player: 'black'));
        _isAiThinking = false;
      });
      _recordMove(row: aiMove.row, col: aiMove.col, player: 1);
    } catch (e) {
      _logger.e('Error requesting AI move: $e');
      if (mounted) setState(() => _isAiThinking = false);
    }
  }

  Future<void> _endGame(
    BuildContext context,
    AppLocalizations l10n, {
    String? forcedWinnerColor,
  }) async {
    final game = _game;
    final stones = _stones;
    if (game == null || stones == null || _gameEnded) return;

    setState(() => _gameEnded = true);
    _countdownTimer?.cancel();

    try {
      String winnerColor;
      if (forcedWinnerColor != null) {
        winnerColor = forcedWinnerColor;
      } else {
        final score = GoScoring.computeAreaScore(stones, widget.boardSize);
        if (score.blackScore == score.whiteScore) {
          winnerColor = 'draw';
        } else {
          winnerColor = score.blackScore > score.whiteScore ? 'black' : 'white';
        }
      }

      // whitePlayer は常に自分(widget.uid)なので、白が勝てば自分の勝ち。
      final result = winnerColor == 'draw'
          ? 'draw'
          : (winnerColor == 'white' ? 'win' : 'loss');

      final sgfData = generateSgfFromMoves(_moves, widget.boardSize);

      var ratingChange = 0;
      if (widget.aiLevel != null) {
        ratingChange = await _updateAiRating(result);
      }

      await ref.read(
        endBlitzGameProvider(
          (
            gameId: game.id,
            result: result,
            winnerColor: winnerColor,
            sgfData: sgfData,
            ratingChange: ratingChange,
          ),
        ).future,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameEndedResultLabel(result))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('Error ending game: $e');
      if (mounted) {
        setState(() => _gameEnded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// AI対局のレーティングを更新し(通常のAI対局のleaderboard反映と同じ
  /// 計算式 - lib/utils/ai_rating.dart参照)、増減量を返す。失敗しても
  /// 対局記録自体の保存は妨げない(best-effort)。
  Future<int> _updateAiRating(String result) async {
    try {
      final aiLevel = int.tryParse(widget.aiLevel ?? '') ?? 5;
      final gameResult = switch (result) {
        'win' => GameResult.playerWin,
        'loss' => GameResult.aiWin,
        _ => GameResult.draw,
      };

      final leaderboardService = ref.read(leaderboardServiceProvider);
      final entry = await leaderboardService.getUserRank(
        uid: widget.uid,
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
      );
      final currentRating = entry?.rating ?? 1200;
      final delta = computeRatingDelta(
        currentRating: currentRating,
        aiLevel: aiLevel,
        result: gameResult,
      );

      await ref.read(incrementUserStatsProvider)(
        uid: widget.uid,
        displayName: 'Player',
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
        newRating: currentRating + delta,
        gamesPlayedDelta: 1,
        winsDelta: gameResult == GameResult.playerWin ? 1 : 0,
      );

      return delta;
    } catch (e) {
      _logger.w('Blitz対局のレーティング反映失敗 (non-fatal): $e');
      return 0;
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.preparingGameMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    String error,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
          const SizedBox(height: 16),
          Text(
            l10n.genericErrorMessage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.goBackButton),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _logger.i('BlitzGameScreen disposed');
    super.dispose();
  }
}

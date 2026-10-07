import 'package:komovia_go/services/go_hints.dart';
import 'package:komovia_go/viewmodels/danger_hints_provider.dart';
import 'package:komovia_go/views/widgets/go_hint_painter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/stone_feedback.dart';
import 'package:komovia_go/utils/wa_decorations.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';
import 'package:komovia_go/views/screens/dead_stone_marking_screen.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// AIGameScreen - Live gameplay against GNU Go engine
///
/// Core features:
/// - Interactive 9x9 Go board (configurable)
/// - Real-time AI move requests with retry logic
/// - Move validation and illegal move prevention
/// - Game ending with score calculation (Chinese rules)
/// - Move-by-move game recording
///
/// Priority: Aha moment path - Capture stone on first move
/// Ink colour for grid lines and star points drawn on the wooden board.
const Color _woodLine = Color(0xB83A2711);

class AIGameScreen extends ConsumerStatefulWidget {
  const AIGameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AIGameScreen> createState() => _AIGameScreenState();
}

class _AIGameScreenState extends ConsumerState<AIGameScreen> {
  /// Fixed height of the evaluation panel so the board never resizes.
  static const double _evaluationPanelHeight = 112;

  late int _selectedRow;
  late int _selectedCol;

  // 捕獲演出用 — イベントIDをキーにしたAnimatedSwitcherで、連続で
  // 石を取ってもその都度新しいアニメーションとして表示させる。
  int _captureEventId = 0;
  int? _captureFlashCount;
  Timer? _aiMoveRequestTimer;

  @override
  void initState() {
    super.initState();
    _logger.i('AIGameScreen initialized');
    _selectedRow = -1;
    _selectedCol = -1;
  }

  @override
  void dispose() {
    _aiMoveRequestTimer?.cancel();
    super.dispose();
  }

  void _triggerCaptureFlash(int count) {
    if (count <= 0) return;
    setState(() {
      _captureEventId++;
      _captureFlashCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final boardState = ref.watch(gameBoardStateProvider);
    final isGameActive = ref.watch(isGameActiveProvider);
    final aiLevel = ref.watch(aiLevelProvider);
    final movesCount = ref.watch(movesCountProvider);
    final moveHistory = ref.watch(moveHistoryProvider);
    final lastMove = moveHistory.isNotEmpty ? moveHistory.last : null;

    // React to the AI's move once Fuego resolves it: apply it to the board
    // (captures included) the same way a human move is applied.
    ref.listen<AsyncValue<AIMove?>>(aiMoveProvider, (previous, next) {
      // While the provider recomputes it keeps the previous move as its
      // value; re-applying that stale move would be illegal (occupied
      // point) or, for a pass, would pass twice.
      if (next.isLoading) return;
      final aiMove = next.valueOrNull;
      if (aiMove == null) return;

      if (aiMove.isPass) {
        _logger.i('AI passed');
        final gameEnded = ref.read(applyPassProvider)();
        ref.read(logCustomEventProvider)(
          eventName: 'ai_pass',
          parameters: {'move_number': ref.read(movesCountProvider)},
        );
        if (gameEnded) {
          _endGameByPasses(context, ref);
        }
        return;
      }

      final beforeCaptures = (
        black: ref.read(gameBoardStateProvider).capturedBlack,
        white: ref.read(gameBoardStateProvider).capturedWhite,
      );
      final applied = ref.read(applyMoveProvider)(aiMove.row, aiMove.col);
      if (!applied) {
        _logger.e(
          '❌ AI returned an illegal move: [${aiMove.row},${aiMove.col}]',
        );
        return;
      }
      final afterState = ref.read(gameBoardStateProvider);
      final capturedDelta =
          (afterState.capturedBlack - beforeCaptures.black) +
          (afterState.capturedWhite - beforeCaptures.white);
      if (capturedDelta > 0) {
        playCaptureFeedback();
        _triggerCaptureFlash(capturedDelta);
      } else {
        playStonePlaceFeedback();
      }

      ref.read(logCustomEventProvider)(
        eventName: 'ai_move',
        parameters: {
          'row': aiMove.row,
          'col': aiMove.col,
          'move_number': ref.read(movesCountProvider),
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(l10n.aiGameScreenTitle(aiLevel)),
        centerTitle: true,
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 青海波の地紋。碁盤や文字を邪魔しない薄さで全面に敷く。
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SeigaihaPatternPainter(
                  color: AppColors.accent.withOpacity(0.04),
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Game info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const HankoSeal(character: '碁'),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.boardSizeLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey500),
                        ),
                        Text(
                          '${boardState.boardSize}×${boardState.boardSize}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          l10n.capturesBlackWhiteLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey500),
                        ),
                        Text(
                          '${boardState.capturedBlack} / ${boardState.capturedWhite}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.movesLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.grey500),
                        ),
                        Text(
                          '$movesCount',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Go board
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: _buildGoBoard(context, ref, boardState, lastMove),
                  ),
                ),
              ),

              // Position evaluation display
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: SizedBox(
                  height: _evaluationPanelHeight,
                  child: _buildPositionEvaluation(context, ref),
                ),
              ),

              // Game controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    // AI move status
                    // 出入りで盤の高さが変わらないよう、枠は常に確保する。
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 28,
                        child: ref.watch(aiMoveProvider).isLoading
                            ? _AiThinkingIndicator(l10n: l10n)
                            : null,
                      ),
                    ),

                    // Button row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isGameActive
                                ? () => _handlePass(context, ref)
                                : null,
                            child: Text(l10n.passButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isGameActive
                                ? () => _handleResign(context, ref)
                                : null,
                            child: Text(l10n.resignButton),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !isGameActive
                                ? () => _handleNewGame(context, ref)
                                : null,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isGameActive
                                    ? l10n.gameInProgressLabel
                                    : l10n.newGameButton,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the interactive Go board
  Widget _buildGoBoard(
    BuildContext context,
    WidgetRef ref,
    BoardState boardState,
    ({int row, int col, String player})? lastMove,
  ) {
    final boardSize = boardState.boardSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = AppLocalizations.of(context)!;
        final boardPixelSize = constraints.biggest.shortestSide;
        final geometry = GoBoardGeometry(
          size: boardPixelSize,
          boardSize: boardSize,
        );

        return GestureDetector(
          onTapDown: (details) {
            if (!ref.read(isGameActiveProvider)) return;
            // Human always plays black; ignore taps while the AI is thinking.
            if (!ref.read(gameBoardStateProvider).isBlackTurn) return;

            final nearest = geometry.nearestIntersection(details.localPosition);
            _handleBoardTap(context, ref, nearest.row, nearest.col);
          },
          child: Container(
            width: boardPixelSize,
            height: boardPixelSize,
            // The frame is drawn as a foreground decoration so it does not
            // inset the child area: grid, stones and taps must all share the
            // exact same boardPixelSize-wide coordinate space.
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryDark, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFC79A5C), // 榧(かや)材の明るい木目色
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
                // Grid lines
                CustomPaint(
                  painter: GoBoardGridPainter(
                    boardSize: boardSize,
                    lineColor: _woodLine,
                    starPointColor: _woodLine,
                  ),
                  size: Size(boardPixelSize, boardPixelSize),
                ),

                // Stones
                ..._buildStones(geometry, boardState.stones),

                // 初心者向け: アタリの石と打てない点の可視化（設定でオフにできる）
                if (ref.watch(dangerHintsProvider))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: GoHintPainter(
                          geometry: geometry,
                          atari: GoHints.atariStones(
                            boardState.stones,
                            boardSize,
                          ),
                          illegal: boardState.isBlackTurn
                              ? GoHints.illegalPoints(
                                  boardState.stones,
                                  boardSize,
                                  1,
                                  koRow: boardState.koRow,
                                  koCol: boardState.koCol,
                                )
                              : const {},
                        ),
                      ),
                    ),
                  ),

                // 直前の一手を示す朱の印
                if (lastMove != null)
                  Positioned(
                    left:
                        geometry.intersectionOffset(lastMove.row, lastMove.col).dx -
                        geometry.pitch * 0.12,
                    top:
                        geometry.intersectionOffset(lastMove.row, lastMove.col).dy -
                        geometry.pitch * 0.12,
                    child: IgnorePointer(
                      child: Container(
                        width: geometry.pitch * 0.24,
                        height: geometry.pitch * 0.24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: lastMove.player == 'black'
                                ? AppColors.washi
                                : AppColors.sumi,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Legal move indicator
                if (_selectedRow >= 0 && _selectedCol >= 0)
                  Positioned(
                    left:
                        geometry.intersectionOffset(_selectedRow, _selectedCol).dx -
                        geometry.pitch * 0.15,
                    top:
                        geometry.intersectionOffset(_selectedRow, _selectedCol).dy -
                        geometry.pitch * 0.15,
                    child: Container(
                      width: geometry.pitch * 0.3,
                      height: geometry.pitch * 0.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withOpacity(0.5),
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                    ),
                  ),

                // Capture celebration flash
                if (_captureFlashCount != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _CaptureFlash(
                        key: ValueKey(_captureEventId),
                        count: _captureFlashCount!,
                        l10n: l10n,
                        onDone: () {
                          if (mounted) {
                            setState(() => _captureFlashCount = null);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build stone widgets
  List<Widget> _buildStones(
    GoBoardGeometry geometry,
    List<List<int>> stones,
  ) {
    final stoneWidgets = <Widget>[];
    final stoneRadius = geometry.pitch * 0.4;

    for (int row = 0; row < geometry.boardSize; row++) {
      for (int col = 0; col < geometry.boardSize; col++) {
        final stone = stones[row][col];
        if (stone != 0) {
          // 0 = empty, 1 = black, 2 = white
          final isBlack = stone == 1;
          final center = geometry.intersectionOffset(row, col);

          stoneWidgets.add(
            Positioned(
              left: center.dx - stoneRadius,
              top: center.dy - stoneRadius,
              child: GoStone(radius: stoneRadius, isBlack: isBlack),
            ),
          );
        }
      }
    }

    return stoneWidgets;
  }

  void _handleBoardTap(BuildContext context, WidgetRef ref, int row, int col) {
    final l10n = AppLocalizations.of(context)!;
    _logger.i('Board tapped: row=$row, col=$col');

    // Applies the move (occupancy/suicide/ko checked internally) and, on
    // success, updates stones, captures, turn and the ko point.
    final beforeCaptures = (
      black: ref.read(gameBoardStateProvider).capturedBlack,
      white: ref.read(gameBoardStateProvider).capturedWhite,
    );
    final applied = ref.read(applyMoveProvider)(row, col);

    if (!applied) {
      _logger.w('Illegal move attempt: [$row,$col]');
      playIllegalMoveFeedback();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.illegalMoveMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final afterState = ref.read(gameBoardStateProvider);
    final capturedDelta =
        (afterState.capturedBlack - beforeCaptures.black) +
        (afterState.capturedWhite - beforeCaptures.white);
    if (capturedDelta > 0) {
      playCaptureFeedback();
      _triggerCaptureFlash(capturedDelta);
    } else {
      playStonePlaceFeedback();
    }

    _logger.i('Legal move applied: [$row,$col]');

    // Log move
    ref.read(logCustomEventProvider)(
      eventName: 'player_move',
      parameters: {
        'row': row,
        'col': col,
        'move_number': ref.read(movesCountProvider),
      },
    );

    // positionEvaluationProvider watches board state directly and
    // recomputes on its own; no manual refresh needed here.

    // Request AI move after a short delay so the player can see their
    // stone land before the AI responds. `aiMoveProvider` itself checks
    // whose turn it is, so an invalidate here is a no-op if this move
    // somehow didn't flip the turn.
    _aiMoveRequestTimer?.cancel();
    _aiMoveRequestTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.invalidate(aiMoveProvider);
      }
    });
  }

  void _handlePass(BuildContext context, WidgetRef ref) {
    if (!ref.read(gameBoardStateProvider).isBlackTurn) return;

    final l10n = AppLocalizations.of(context)!;
    _logger.i('Player passed');
    final gameEnded = ref.read(applyPassProvider)();

    ref.read(logCustomEventProvider)(
      eventName: 'player_pass',
      parameters: {'move_number': ref.read(movesCountProvider)},
    );

    if (gameEnded) {
      _endGameByPasses(context, ref);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.passedMessage),
        duration: const Duration(seconds: 2),
      ),
    );

    // Let the AI respond, same pacing as after a stone placement.
    _aiMoveRequestTimer?.cancel();
    _aiMoveRequestTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.invalidate(aiMoveProvider);
      }
    });
  }

  /// Two consecutive passes: let the player confirm dead stones (the native
  /// Fuego safety solver that could do this automatically isn't bundled in
  /// most builds), then score the game and move to the result screen.
  void _endGameByPasses(BuildContext context, WidgetRef ref) {
    _logger.i('🏁 Game ended by two consecutive passes');
    ref.read(isGameActiveProvider.notifier).state = false;

    final boardState = ref.read(gameBoardStateProvider);
    final aiEngine = ref.read(aiEngineServiceProvider);
    final suggestedDeadPoints = aiEngine
        .suggestDeadStones(stones: boardState.stones, boardSize: boardState.boardSize)
        .toSet();

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeadStoneMarkingScreen(
          stones: boardState.stones,
          boardSize: boardState.boardSize,
          suggestedDeadPoints: suggestedDeadPoints,
          onConfirm: (deadPoints) => _finishGameWithDeadStones(
            context,
            ref,
            boardState: boardState,
            deadPoints: deadPoints,
          ),
        ),
      ),
    );
  }

  void _finishGameWithDeadStones(
    BuildContext context,
    WidgetRef ref, {
    required BoardState boardState,
    required Set<(int, int)> deadPoints,
  }) {
    try {
      final aiEngine = ref.read(aiEngineServiceProvider);
      final result = aiEngine.scoreWithDeadStones(
        boardSize: boardState.boardSize,
        stones: boardState.stones,
        deadPoints: deadPoints,
      );
      ref.read(gameResultProvider.notifier).state = result;

      final resultLabel = result.winner == 'black'
          ? 'win'
          : result.winner == 'white'
          ? 'lose'
          : 'draw';

      ref.read(logCustomEventProvider)(
        eventName: 'ai_game_completed',
        parameters: {
          'result': resultLabel,
          'ai_level': ref.read(aiLevelProvider),
        },
      );

      Navigator.of(context).pushReplacementNamed(
        '/game-result',
        arguments: {
          'result': resultLabel,
          'blackScore': result.blackScore,
          'whiteScore': result.whiteScore,
        },
      );
    } catch (e) {
      _logger.e('❌ Failed to judge game end: $e');
    }
  }

  void _handleResign(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    _logger.w('Player resigned');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: Text(l10n.resignConfirmTitle),
        content: Text(l10n.resignConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(logGameResignationProvider)(
                aiLevel: ref.read(aiLevelProvider),
                boardSize: ref.read(gameBoardStateProvider).boardSize,
                movesCount: ref.read(movesCountProvider),
              );
              // Mark inactive so the board/buttons freeze immediately;
              // startNewGameProvider (via New Game / Play Again) is what
              // actually resets state for the next game.
              ref.read(isGameActiveProvider.notifier).state = false;
              Navigator.of(context).pushReplacementNamed(
                '/game-result',
                arguments: {'result': 'resign'},
              );
            },
            child: Text(l10n.confirmResignButton),
          ),
        ],
      ),
    );
  }

  void _handleNewGame(BuildContext context, WidgetRef ref) {
    _logger.i('Starting new game');
    ref.read(startNewGameProvider)();
  }

  /// 無料ユーザー向けの、形勢判断のロック表示。
  Widget _buildAnalysisLocked(BuildContext context, AppLocalizations l10n) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pushNamed('/paywall'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.kin.withOpacity(0.6), width: 1),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.kin.withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 20, color: AppColors.kin),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.analysisLockedMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.washi,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.analysisLockedAction,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.kin,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: AppColors.kin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build position evaluation widget
  Widget _buildPositionEvaluation(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // 形勢判断の詳細（目差・勝率）はプレミアム機能。無料ユーザーには
    // 計算も走らせず、ロック表示から課金画面へ誘導する。
    if (!ref.watch(isSubscriptionActiveProvider)) {
      return _buildAnalysisLocked(context, l10n);
    }
    final evaluation = ref.watch(positionEvaluationProvider);

    // 再計算中は直前の評価を表示し続け、パネルの中身と高さを変えない。
    return evaluation.when(
      skipLoadingOnReload: true,
      data: (eval) {
        final scoreDiff = eval.scoreDiff;
        final assessment = eval.assessment;
        final blackWinProb = eval.blackWinProb;

        // Determine color based on score difference
        final evalColor = scoreDiff > 0
            ? AppColors.aiLight // Black winning
            : scoreDiff < 0
            ? Colors.orange[400]! // White winning
            : AppColors.accent; // Even

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: evalColor, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.washiDim.withOpacity(0.5),
          ),
          child: Column(
            children: [
              // Assessment text
              Text(
                assessment,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: evalColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Score difference display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.scoreDiffLabel(scoreDiff.toStringAsFixed(1)),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.washiDim),
                  ),
                  Text(
                    l10n.blackWinRateLabel(
                      (blackWinProb * 100).toStringAsFixed(1),
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.washiDim),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Win probability bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: blackWinProb,
                  minHeight: 8,
                  backgroundColor: AppColors.grey500,
                  valueColor: AlwaysStoppedAnimation(evalColor),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey500, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.washiDim.withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.calculatingPositionMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.washiDim),
            ),
          ],
        ),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.shuLight, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.shuDark.withOpacity(0.2),
        ),
        child: Text(
          l10n.positionEvaluationErrorMessage,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.shuLight),
        ),
      ),
    );
  }

}

/// AIの「考え中」演出。墨がにじむような、ゆっくり明滅する円で表現する。
class _AiThinkingIndicator extends StatefulWidget {
  final AppLocalizations l10n;

  const _AiThinkingIndicator({required this.l10n});

  @override
  State<_AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<_AiThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<String> _phrases;
  int _phraseIndex = 0;
  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();
    _phrases = [
      widget.l10n.aiThinkingPhrase1,
      widget.l10n.aiThinkingPhrase2,
      widget.l10n.aiThinkingPhrase3,
    ];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _cyclePhrase();
  }

  void _cyclePhrase() {
    _phraseTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
      _cyclePhrase();
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sumi.withOpacity(0.25 + 0.35 * t),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.4 + 0.4 * t),
                  width: 1.5,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Text(
          _phrases[_phraseIndex],
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.grey300),
        ),
      ],
    );
  }
}


/// 捕獲時の演出。「アゲハマができた瞬間」を気持ちよく見せるための、
/// フェードイン→少し留まる→フェードアウトするだけの軽量な演出。
/// AnimationController/TickerProviderは使わず、Future.delayed +
/// AnimatedOpacity/AnimatedScaleだけで完結させている。
class _CaptureFlash extends StatefulWidget {
  final int count;
  final AppLocalizations l10n;
  final VoidCallback onDone;

  const _CaptureFlash({
    super.key,
    required this.count,
    required this.l10n,
    required this.onDone,
  });

  @override
  State<_CaptureFlash> createState() => _CaptureFlashState();
}

class _CaptureFlashState extends State<_CaptureFlash> {
  bool _visible = false;
  Timer? _fadeOutTimer;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _fadeOutTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visible = false);
    });
    _doneTimer = Timer(const Duration(milliseconds: 1300), widget.onDone);
  }

  @override
  void dispose() {
    _fadeOutTimer?.cancel();
    _doneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: AnimatedScale(
          scale: _visible ? 1.0 : 0.7,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sumi.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: Text(
              widget.count > 1
                  ? widget.l10n.captureFlashMultipleMessage(widget.count)
                  : widget.l10n.captureFlashSingleMessage,
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/pvp_game.dart';
import 'package:komovia_go/services/pvp_game_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/stone_feedback.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// PvP対局画面 - マッチング成立後の2人プレイヤー間リアルタイム対局
class PvpGameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String uid;

  const PvpGameScreen({Key? key, required this.gameId, required this.uid}) : super(key: key);

  @override
  ConsumerState<PvpGameScreen> createState() => _PvpGameScreenState();
}

class _PvpGameScreenState extends ConsumerState<PvpGameScreen> {
  bool _isSubmittingMove = false;
  bool _resultShown = false;

  // 捕獲演出用。どちらのプレイヤーが打っても、両者の画面で捕獲の瞬間が
  // 見えるようにストリームの値そのものを監視して検知する。
  int? _lastCapturedBlack;
  int? _lastCapturedWhite;
  int _captureEventId = 0;
  int? _captureFlashCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gameAsync = ref.watch(pvpGameStreamProvider(widget.gameId));

    ref.listen<AsyncValue<PvpGame?>>(pvpGameStreamProvider(widget.gameId), (previous, next) {
      final game = next.valueOrNull;
      if (game == null) return;
      if (_lastCapturedBlack != null && _lastCapturedWhite != null) {
        final delta = (game.capturedBlack - _lastCapturedBlack!) +
            (game.capturedWhite - _lastCapturedWhite!);
        if (delta > 0) {
          setState(() {
            _captureEventId++;
            _captureFlashCount = delta;
          });
        }
      }
      _lastCapturedBlack = game.capturedBlack;
      _lastCapturedWhite = game.capturedWhite;
    });

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.pvpGameTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: gameAsync.when(
        data: (game) {
          if (game == null) {
            return Center(
              child: Text(l10n.gameNotFoundMessage, style: TextStyle(color: AppColors.washiDim)),
            );
          }

          if (game.isFinished) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog(context, game));
          }

          return _buildContent(context, l10n, game);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          _logger.e('PvP game stream error: $err');
          return Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)));
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, PvpGame game) {
    final isMyTurn = game.isActive && game.isTurnOf(widget.uid);
    final myColor = game.playerColorOf(widget.uid);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPlayersHeader(l10n, game, isMyTurn),
          const SizedBox(height: 20),
          Center(child: _buildBoard(context, game, isMyTurn)),
          const SizedBox(height: 16),
          Text(
            l10n.moveCaptureStatusLabel(
              game.movesCount,
              game.capturedWhite,
              game.capturedBlack,
            ),
            style: TextStyle(color: AppColors.washiDim, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (game.isActive && myColor != 0) _buildControls(context, l10n, game),
          if (game.canClaimAbandonmentForfeit(
            widget.uid,
            threshold: PvpGameService.abandonmentThreshold,
          ))
            _buildAbandonmentClaimCard(context, l10n, game),
        ],
      ),
    );
  }

  Widget _buildPlayersHeader(AppLocalizations l10n, PvpGame game, bool isMyTurn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPlayerBadge(l10n, game.blackDisplayName, isBlack: true, isTurn: game.isActive && game.isBlackTurn),
        Text(l10n.vsLabel, style: TextStyle(color: AppColors.washiDim)),
        _buildPlayerBadge(l10n, game.whiteDisplayName, isBlack: false, isTurn: game.isActive && !game.isBlackTurn),
      ],
    );
  }

  Widget _buildPlayerBadge(AppLocalizations l10n, String name, {required bool isBlack, required bool isTurn}) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBlack ? AppColors.sumi : AppColors.washi,
            border: isTurn ? Border.all(color: AppColors.kin, width: 3) : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: AppColors.washi, fontSize: 13)),
        if (isTurn) Text(l10n.turnIndicatorLabel, style: TextStyle(color: AppColors.kin, fontSize: 11)),
      ],
    );
  }

  Widget _buildBoard(BuildContext context, PvpGame game, bool isMyTurn) {
    final boardSize = game.boardSize;
    const boardPixelSize = 320.0;
    final geometry = GoBoardGeometry(size: boardPixelSize, boardSize: boardSize);

    return GestureDetector(
      onTapDown: (details) {
        if (!isMyTurn || _isSubmittingMove) return;
        final nearest = geometry.nearestIntersection(details.localPosition);
        _handleTap(game, nearest.row, nearest.col);
      },
      child: Container(
        width: boardPixelSize,
        height: boardPixelSize,
        decoration: BoxDecoration(
          border: Border.all(
            color: isMyTurn ? AppColors.kin : AppColors.washiDim,
            width: isMyTurn ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.kin.withOpacity(0.35),
              Colors.brown[700]!.withOpacity(0.45),
              AppColors.kin.withOpacity(0.35),
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
                boardSize: boardSize,
                lineColor: AppColors.sumi,
                starPointColor: Colors.black54,
              ),
              size: const Size(boardPixelSize, boardPixelSize),
            ),
            ..._buildStones(geometry, game.stones),
            if (game.lastMoveRow != null && game.lastMoveCol != null)
              Positioned(
                left:
                    geometry.intersectionOffset(game.lastMoveRow!, game.lastMoveCol!).dx -
                    geometry.pitch * 0.12,
                top:
                    geometry.intersectionOffset(game.lastMoveRow!, game.lastMoveCol!).dy -
                    geometry.pitch * 0.12,
                child: Container(
                  width: geometry.pitch * 0.24,
                  height: geometry.pitch * 0.24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                ),
              ),
            if (_captureFlashCount != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _CaptureFlash(
                    key: ValueKey(_captureEventId),
                    count: _captureFlashCount!,
                    l10n: AppLocalizations.of(context)!,
                    onDone: () {
                      if (mounted) setState(() => _captureFlashCount = null);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStones(GoBoardGeometry geometry, List<List<int>> stones) {
    final stoneWidgets = <Widget>[];
    final stoneRadius = geometry.pitch * 0.4;

    for (int row = 0; row < geometry.boardSize; row++) {
      for (int col = 0; col < geometry.boardSize; col++) {
        final stone = stones[row][col];
        if (stone != 0) {
          final isBlack = stone == 1;
          final border = isBlack ? null : Border.all(color: AppColors.washiDim, width: 0.5);
          final center = geometry.intersectionOffset(row, col);
          stoneWidgets.add(
            Positioned(
              left: center.dx - stoneRadius,
              top: center.dy - stoneRadius,
              child: Container(
                width: stoneRadius * 2,
                height: stoneRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: border,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    radius: 0.9,
                    colors: isBlack
                        ? [AppColors.washiDim, AppColors.sumi]
                        : [AppColors.washi, AppColors.washiDim],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(1.5, 2.5)),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }
    return stoneWidgets;
  }

  Widget _buildControls(BuildContext context, AppLocalizations l10n, PvpGame game) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _handlePass(game),
          icon: const Icon(Icons.skip_next),
          label: Text(l10n.passButton),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          onPressed: () => _confirmResign(context, game),
          icon: const Icon(Icons.flag),
          label: Text(l10n.resignButton),
        ),
      ],
    );
  }

  Widget _buildAbandonmentClaimCard(BuildContext context, AppLocalizations l10n, PvpGame game) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            l10n.opponentInactiveMessage,
            style: const TextStyle(color: AppColors.shuLight),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.shuLight),
            onPressed: () => _confirmClaimForfeit(context, game),
            child: Text(l10n.claimForfeitButton),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClaimForfeit(BuildContext context, PvpGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.claimForfeitConfirmTitle, style: const TextStyle(color: AppColors.washi)),
        content: Text(l10n.claimForfeitConfirmContent, style: TextStyle(color: AppColors.washiDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton, style: TextStyle(color: AppColors.aiLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.claimForfeitButton, style: TextStyle(color: AppColors.shuLight)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(claimAbandonmentForfeitProvider)(widget.gameId, widget.uid);
    } catch (e) {
      _logger.e('Error claiming forfeit: $e');
    }
  }

  Future<void> _handleTap(PvpGame game, int row, int col) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSubmittingMove = true);
    try {
      final success = await ref.read(applyPvpMoveProvider)(widget.gameId, widget.uid, row, col);
      if (success) {
        playStonePlaceFeedback();
      } else {
        playIllegalMoveFeedback();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.illegalPvpMoveMessage)),
          );
        }
      }
    } catch (e) {
      _logger.e('Error applying move: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingMove = false);
    }
  }

  Future<void> _handlePass(PvpGame game) async {
    try {
      await ref.read(passPvpGameProvider)(widget.gameId, widget.uid);
    } catch (e) {
      _logger.e('Error passing: $e');
    }
  }

  Future<void> _confirmResign(BuildContext context, PvpGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.resignConfirmTitle, style: const TextStyle(color: AppColors.washi)),
        content: Text(l10n.resignPvpConfirmContent, style: const TextStyle(color: AppColors.washiDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton, style: TextStyle(color: AppColors.aiLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmResignButton, style: TextStyle(color: AppColors.shuLight)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(resignPvpGameProvider)(widget.gameId, widget.uid);
      } catch (e) {
        _logger.e('Error resigning: $e');
      }
    }
  }

  void _showResultDialog(BuildContext context, PvpGame game) {
    if (_resultShown) return;
    _resultShown = true;

    final l10n = AppLocalizations.of(context)!;
    final won = game.winnerUid == widget.uid;
    final isDraw = game.winnerUid == null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(
          isDraw
              ? l10n.pvpDrawResultTitle
              : (won ? l10n.pvpWinResultTitle : l10n.pvpLoseResultTitle),
          style: const TextStyle(color: AppColors.washi),
        ),
        content: Text(
          _resultDescription(l10n, game),
          style: const TextStyle(color: AppColors.washiDim),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(l10n.closeButton, style: TextStyle(color: AppColors.kin)),
          ),
          // トーナメント試合はブラケットの対戦順で決まるため、その場での
          // 再戦は対象外（通常の対局・マッチング経由の対局のみ）。
          if (game.tournamentId == null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleRematch(context, game);
              },
              child: Text(l10n.rematchButton, style: TextStyle(color: AppColors.kin)),
            ),
        ],
      ),
    );
  }

  /// 同じ相手ともう一局。色入れ替え・相手への通知はrematchPvpGameProvider
  /// 側の責務（ロジックをテスト可能にするため、resignPvpGameProvider等と
  /// 同じくプロバイダー層に置いている）。
  Future<void> _handleRematch(BuildContext context, PvpGame game) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final newGame = await ref.read(rematchPvpGameProvider)(game, widget.uid);

      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PvpGameScreen(gameId: newGame.id, uid: widget.uid)),
      );
    } catch (e) {
      _logger.e('Error starting rematch: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rematchFailedMessage)),
        );
      }
    }
  }

  String _resultDescription(AppLocalizations l10n, PvpGame game) {
    if (game.result == 'resignation') return l10n.resignationResultLabel;
    if (game.result == 'forfeit') return l10n.forfeitResultLabel;
    if (game.blackScore != null && game.whiteScore != null) {
      return l10n.scoreResultLabel(
        game.blackScore!.toStringAsFixed(1),
        game.whiteScore!.toStringAsFixed(2),
      );
    }
    return l10n.territoryCountResultLabel;
  }
}

/// 捕獲時の演出。ai_game_screen.dartの同名ウィジェットと同じ内容だが、
/// privateクラスなので共有できず、このファイル内に複製している。
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _visible = false);
    });
    Future.delayed(const Duration(milliseconds: 1300), widget.onDone);
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
              border: Border.all(color: AppColors.kin, width: 2),
            ),
            child: Text(
              widget.count > 1
                  ? widget.l10n.captureFlashMultipleMessage(widget.count)
                  : widget.l10n.captureFlashSingleMessage,
              style: TextStyle(
                color: AppColors.kin,
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

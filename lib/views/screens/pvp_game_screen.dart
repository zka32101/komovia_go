import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';
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
import 'package:komovia_go/views/screens/dead_stone_marking_screen.dart';

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

  // 時計はクライアント側でのライブ表示専用（Firestore側には手が打たれた
  // 時点のバンク値のみ保存されている）。1秒ごとに再描画して残り時間を
  // 更新する — ドキュメント自体は更新しない。
  Timer? _clockTicker;

  @override
  void initState() {
    super.initState();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

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

          if (game.isScoring) {
            return _buildScoringContent(context, l10n, game);
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
          if (game.isActive && game.canClaimTimeoutForfeit(widget.uid, DateTime.now()))
            _buildTimeoutClaimCard(context, l10n, game)
          else if (game.canClaimAbandonmentForfeit(
            widget.uid,
            threshold: PvpGameService.abandonmentThreshold,
          ))
            _buildAbandonmentClaimCard(context, l10n, game),
        ],
      ),
    );
  }

  /// 終局処理のための死石マーキング段階（status == 'scoring'）。自分がまだ
  /// 提出していなければDeadStoneMarkingScreenを表示し、提出済みなら相手の
  /// 提出を待つ画面を表示する。両者の提出が一致すればsubmitDeadStones側で
  /// 自動的に'finished'へ進むため、このウィジェットはpvpGameStreamProvider
  /// の更新を受けて自然に次の状態（待機→終局 or 不一致でactiveへ戻る）へ
  /// 遷移する。
  Widget _buildScoringContent(BuildContext context, AppLocalizations l10n, PvpGame game) {
    final myColor = game.playerColorOf(widget.uid);
    if (myColor == 0) {
      return Center(
        child: Text(l10n.deadStoneMarkingWaitingMessage, style: TextStyle(color: AppColors.washiDim)),
      );
    }

    final isBlack = myColor == 1;
    final mySubmission = isBlack ? game.blackDeadStones : game.whiteDeadStones;

    if (mySubmission == null) {
      return DeadStoneMarkingScreen(
        stones: game.stones,
        boardSize: game.boardSize,
        onConfirm: (deadPoints) async {
          try {
            await ref.read(submitDeadStonesProvider)(widget.gameId, widget.uid, deadPoints);
          } catch (e) {
            _logger.e('Error submitting dead stones: $e');
          }
        },
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.deadStoneMarkingWaitingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.washiDim),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersHeader(AppLocalizations l10n, PvpGame game, bool isMyTurn) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPlayerBadge(
          l10n,
          game.blackDisplayName,
          isBlack: true,
          isTurn: game.isActive && game.isBlackTurn,
          remainingMs: game.remainingMs(true, now),
        ),
        Text(l10n.vsLabel, style: TextStyle(color: AppColors.washiDim)),
        _buildPlayerBadge(
          l10n,
          game.whiteDisplayName,
          isBlack: false,
          isTurn: game.isActive && !game.isBlackTurn,
          remainingMs: game.remainingMs(false, now),
        ),
      ],
    );
  }

  Widget _buildPlayerBadge(
    AppLocalizations l10n,
    String name, {
    required bool isBlack,
    required bool isTurn,
    required int remainingMs,
  }) {
    final isLow = remainingMs < 30000;
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
        Text(
          _formatClock(remainingMs),
          style: TextStyle(
            color: isLow ? AppColors.shuLight : AppColors.washiDim,
            fontSize: 12,
            fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (isTurn) Text(l10n.turnIndicatorLabel, style: TextStyle(color: AppColors.kin, fontSize: 11)),
      ],
    );
  }

  String _formatClock(int ms) {
    final totalSeconds = (ms / 1000).ceil().clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeoutClaimCard(BuildContext context, AppLocalizations l10n, PvpGame game) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Text(
            l10n.opponentTimeExpiredMessage,
            style: const TextStyle(color: AppColors.shuLight),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.shuLight),
            onPressed: () => _confirmClaimTimeout(context, game),
            child: Text(l10n.claimTimeoutButton),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClaimTimeout(BuildContext context, PvpGame game) async {
    try {
      await ref.read(claimTimeoutForfeitProvider)(widget.gameId, widget.uid);
    } catch (e) {
      _logger.e('Error claiming timeout forfeit: $e');
    }
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
            colors: ref.watch(selectedBoardSkinProvider).gradient,
          ),
          image: ref.watch(selectedBoardSkinProvider).textureAsset == null
              ? null
              : DecorationImage(
                  image: AssetImage(ref.watch(selectedBoardSkinProvider).textureAsset!),
                  fit: BoxFit.cover,
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
                lineColor: ref.watch(selectedBoardSkinProvider).lineColor,
                starPointColor: ref.watch(selectedBoardSkinProvider).lineColor,
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
          final center = geometry.intersectionOffset(row, col);
          stoneWidgets.add(
            Positioned(
              left: center.dx - stoneRadius,
              top: center.dy - stoneRadius,
              child: GoStone(
                radius: stoneRadius,
                isBlack: isBlack,
                skin: ref.watch(selectedStoneSkinProvider),
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
    if (game.result == 'timeout') return l10n.timeoutResultLabel;
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

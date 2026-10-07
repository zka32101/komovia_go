import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/spectator.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// ライブ観戦画面 - フレンドの対局盤面をリアルタイムに表示する
class SpectatorViewScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SpectatorViewScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  ConsumerState<SpectatorViewScreen> createState() => _SpectatorViewScreenState();
}

class _SpectatorViewScreenState extends ConsumerState<SpectatorViewScreen> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionAsync = ref.watch(spectatorSessionStreamProvider(widget.sessionId));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.liveSpectateTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return Center(
              child: Text(l10n.spectatorSessionNotFoundMessage, style: TextStyle(color: AppColors.washiDim)),
            );
          }
          return _buildContent(context, l10n, session);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          _logger.e('Spectator session stream error: $err');
          return Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)));
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, SpectatorSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: session.isActive ? Colors.redAccent : Colors.grey,
                radius: 6,
              ),
              const SizedBox(width: 8),
              Text(
                session.hostDisplayName ?? l10n.homeDefaultPlayerName,
                style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Text(
                session.isActive ? l10n.liveLabel : l10n.endedLabel,
                style: TextStyle(
                  color: session.isActive ? Colors.redAccent : AppColors.washiDim,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.spectatorMoveCountLabel(session.moveIndex, session.spectatorCount),
            style: TextStyle(color: AppColors.washiDim, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Center(child: _buildBoard(session)),
          const SizedBox(height: 24),
          _buildLegend(l10n),
          const SizedBox(height: 24),
          const Divider(color: AppColors.washiDim),
          _buildComments(context, l10n, session),
        ],
      ),
    );
  }

  Widget _buildComments(BuildContext context, AppLocalizations l10n, SpectatorSession session) {
    final currentUser = ref.watch(currentUserProvider);
    final commentsAsync = ref.watch(spectatorCommentsProvider(widget.sessionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.commentsTitle,
          style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.noCommentsYetMessage, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
              );
            }
            return Column(
              children: comments
                  .map((c) => _buildCommentTile(c, currentUser?.uid))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Text(l10n.commentsFetchFailedMessage('$err'), style: const TextStyle(color: Colors.redAccent)),
        ),
        if (currentUser != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: AppColors.washi),
                  decoration: InputDecoration(
                    hintText: l10n.commentInputHint,
                    hintStyle: TextStyle(color: AppColors.washiDim),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.kin),
                onPressed: () => _sendComment(
                  currentUser.uid,
                  currentUser.displayName ?? l10n.homeDefaultPlayerName,
                  session.moveIndex,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCommentTile(SpectatorComment comment, String? currentUid) {
    final liked = currentUid != null && comment.likes.contains(currentUid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${comment.displayName}  ',
                    style: const TextStyle(color: AppColors.kin, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextSpan(
                    text: comment.comment,
                    style: const TextStyle(color: AppColors.washi, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (currentUid != null)
            GestureDetector(
              onTap: () => _toggleLike(comment, currentUid, liked),
              child: Row(
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: liked ? Colors.redAccent : AppColors.washiDim,
                  ),
                  if (comment.likes.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text('${comment.likes.length}', style: TextStyle(color: AppColors.washiDim, fontSize: 11)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendComment(String uid, String displayName, int moveIndex) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      await ref.read(addSpectatorCommentProvider)(widget.sessionId, uid, displayName, text, moveIndex);
      ref.invalidate(spectatorCommentsProvider(widget.sessionId));
    } catch (e) {
      _logger.e('Failed to send spectator comment: $e');
    }
  }

  Future<void> _toggleLike(SpectatorComment comment, String uid, bool liked) async {
    try {
      if (liked) {
        await ref.read(unlikeSpectatorCommentProvider)(widget.sessionId, comment.id, uid);
      } else {
        await ref.read(likeSpectatorCommentProvider)(widget.sessionId, comment.id, uid);
      }
      ref.invalidate(spectatorCommentsProvider(widget.sessionId));
    } catch (e) {
      _logger.e('Failed to toggle spectator comment like: $e');
    }
  }

  Widget _buildBoard(SpectatorSession session) {
    final boardSize = session.boardSize;
    final stones = session.stones ?? List.generate(boardSize, (_) => List.filled(boardSize, 0));
    const boardPixelSize = 300.0;
    final geometry = GoBoardGeometry(size: boardPixelSize, boardSize: boardSize);

    return Container(
      width: boardPixelSize,
      height: boardPixelSize,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.kin, width: 2),
        color: AppColors.kinLight.withOpacity(0.1),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: GoBoardGridPainter(
              boardSize: boardSize,
              lineColor: AppColors.sumi,
              starPointColor: null,
            ),
            size: const Size(boardPixelSize, boardPixelSize),
          ),
          ..._buildStones(geometry, stones),
          if (session.lastMoveRow != null && session.lastMoveCol != null)
            Positioned(
              left:
                  geometry.intersectionOffset(session.lastMoveRow!, session.lastMoveCol!).dx -
                  geometry.pitch * 0.12,
              top:
                  geometry.intersectionOffset(session.lastMoveRow!, session.lastMoveCol!).dy -
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
        ],
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
          final color = stone == 1 ? AppColors.sumi : AppColors.washi;
          final border = stone == 1 ? null : Border.all(color: AppColors.sumi, width: 1);
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
                  color: color,
                  border: border,
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(2, 2)),
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

  Widget _buildLegend(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, color: Colors.redAccent.withOpacity(0.8), size: 12),
        const SizedBox(width: 4),
        Text(l10n.lastMoveLegendLabel, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
      ],
    );
  }
}

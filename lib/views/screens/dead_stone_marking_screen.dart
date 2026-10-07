import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/utils/wa_decorations.dart';
import 'package:komovia_go/views/widgets/go_board_grid_painter.dart';

/// 終局後の死石確認ステップ。ネイティブのFuego安全性読みが使えないビルド
/// （このサンドボックスを含むほとんどの実行環境）では自動死石判定ができ
/// ないため、OGS/KGS/Tygemなど他の囲碁アプリと同じく、対局者自身が死んで
/// いる石をタップして取り除く手動確認を挟む。盤面に残った石を全て生存
/// として数える旧来のフォールバックより、実際の対局結果を正しく反映する。
/// Ink colour for grid lines and star points drawn on the wooden board.
const Color _woodLine = Color(0xB83A2711);

class DeadStoneMarkingScreen extends StatefulWidget {
  final List<List<int>> stones;
  final int boardSize;

  /// ネイティブの安全性読みが使える場合の初期提案（無ければ空集合）。
  final Set<(int, int)> suggestedDeadPoints;

  final void Function(Set<(int, int)> deadPoints) onConfirm;

  const DeadStoneMarkingScreen({
    super.key,
    required this.stones,
    required this.boardSize,
    required this.onConfirm,
    this.suggestedDeadPoints = const {},
  });

  @override
  State<DeadStoneMarkingScreen> createState() => _DeadStoneMarkingScreenState();
}

class _DeadStoneMarkingScreenState extends State<DeadStoneMarkingScreen> {
  late Set<(int, int)> _deadPoints;

  @override
  void initState() {
    super.initState();
    _deadPoints = {...widget.suggestedDeadPoints};
  }

  void _toggleGroupAt(int row, int col) {
    final group = GoRules.groupAt(widget.stones, widget.boardSize, row, col);
    if (group.isEmpty) return;

    setState(() {
      final alreadyDead = _deadPoints.contains((row, col));
      if (alreadyDead) {
        _deadPoints.removeAll(group);
      } else {
        _deadPoints.addAll(group);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scoringStones = GoScoring.withDeadStonesRemoved(widget.stones, _deadPoints);
    final score = GoScoring.computeAreaScore(scoringStones, widget.boardSize);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.deadStoneMarkingTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                l10n.deadStoneMarkingInstructions,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildBoard(context),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    l10n.deadStoneMarkingBlackScoreLabel(
                      score.blackScore.toStringAsFixed(1),
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.washi,
                    ),
                  ),
                  Text(
                    l10n.deadStoneMarkingWhiteScoreLabel(
                      score.whiteScore.toStringAsFixed(1),
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.washi,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (_deadPoints.isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _deadPoints.clear()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.washiDim,
                          side: const BorderSide(color: AppColors.sumiLine),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(l10n.deadStoneMarkingResetButton),
                      ),
                    ),
                  if (_deadPoints.isNotEmpty) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => widget.onConfirm(_deadPoints),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kin,
                        foregroundColor: AppColors.sumi,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(l10n.deadStoneMarkingConfirmButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardPixelSize = constraints.biggest.shortestSide;
        final geometry = GoBoardGeometry(
          size: boardPixelSize,
          boardSize: widget.boardSize,
        );

        return GestureDetector(
          onTapDown: (details) {
            final nearest = geometry.nearestIntersection(details.localPosition);
            _toggleGroupAt(nearest.row, nearest.col);
          },
          child: Container(
            width: boardPixelSize,
            height: boardPixelSize,
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: WoodGrainPainter(
                        color: AppColors.sumi.withOpacity(0.08),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: GoBoardGridPainter(
                    boardSize: widget.boardSize,
                    lineColor: _woodLine,
                    starPointColor: _woodLine,
                  ),
                  size: Size(boardPixelSize, boardPixelSize),
                ),
                ..._buildStones(geometry),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildStones(GoBoardGeometry geometry) {
    final stoneWidgets = <Widget>[];
    final stoneRadius = geometry.pitch * 0.4;

    for (int row = 0; row < geometry.boardSize; row++) {
      for (int col = 0; col < geometry.boardSize; col++) {
        final stone = widget.stones[row][col];
        if (stone == 0) continue;

        final isBlack = stone == 1;
        final isDead = _deadPoints.contains((row, col));
        final center = geometry.intersectionOffset(row, col);

        stoneWidgets.add(
          Positioned(
            left: center.dx - stoneRadius,
            top: center.dy - stoneRadius,
            child: Opacity(
              opacity: isDead ? 0.35 : 1.0,
              child: GoStone(
                radius: stoneRadius,
                isBlack: isBlack,
                child: isDead
                    ? Icon(
                        Icons.close,
                        size: stoneRadius * 1.3,
                        color: isBlack ? AppColors.washi : AppColors.shu,
                      )
                    : null,
              ),
            ),
          ),
        );
      }
    }

    return stoneWidgets;
  }
}

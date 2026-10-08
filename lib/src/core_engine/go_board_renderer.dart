import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/views/widgets/go_board_grid_painter.dart';

import 'go_position.dart';

/// Go's `BoardRenderer<GoPosition, Widget>`, composing the board's two
/// already-shared primitives — `GoBoardGeometry` (intersection<->pixel
/// mapping) and `GoBoardGridPainter` (grid lines + star points) — with a
/// new, minimal stone-rendering layer.
///
/// Unlike shogi (`MiniBoardWidget`, one reusable board widget every
/// screen already calls), komovia_go has no equivalent shared "draw the
/// stones" widget: each of the 7 board screens
/// (`ai_game_screen.dart`/`pvp_game_screen.dart`/`tsume_go_screen.dart`/
/// etc.) builds its own stone layer inline, with its own extra visual
/// flourishes (capture-flash overlays, danger-hint painters, wood-grain
/// containers). [build] intentionally does not reproduce any of that
/// screen-specific polish — it only needs to satisfy the shared contract
/// (render the position, highlight last move/hints/selection), the same
/// level `ShogiBoardRenderer` operates at.
class GoBoardRenderer implements core.BoardRenderer<GoPosition, Widget> {
  @override
  Widget build(
    GoPosition position, {
    core.Move? lastMove,
    List<core.Square> hints = const [],
    core.Square? selected,
  }) {
    final board = position.boardState;

    (int, int)? lastRowCol;
    switch (lastMove) {
      case core.DropMove(to: final to):
        lastRowCol = (to.rank, to.file);
      case core.BoardMove():
      case core.PassMove():
      case core.ResignMove():
      case null:
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardPixelSize = constraints.biggest.shortestSide;
        final geometry = GoBoardGeometry(
          size: boardPixelSize,
          boardSize: board.boardSize,
        );

        return SizedBox(
          width: boardPixelSize,
          height: boardPixelSize,
          child: Stack(
            children: [
              CustomPaint(
                painter: GoBoardGridPainter(boardSize: board.boardSize),
                size: Size(boardPixelSize, boardPixelSize),
              ),
              CustomPaint(
                painter: _GoStonesPainter(
                  stones: board.stones,
                  geometry: geometry,
                  lastMove: lastRowCol,
                  hints: {for (final s in hints) (s.rank, s.file)},
                  selected: selected == null ? null : (selected.rank, selected.file),
                ),
                size: Size(boardPixelSize, boardPixelSize),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  core.Square? squareAt(
    core.BoardOffset offset,
    core.BoardSize size,
    GoPosition position,
  ) {
    if (offset.dx < 0 || offset.dx > size.width || offset.dy < 0 || offset.dy > size.height) {
      return null;
    }
    final geometry = GoBoardGeometry(
      size: size.width,
      boardSize: position.boardState.boardSize,
    );
    final nearest = geometry.nearestIntersection(Offset(offset.dx, offset.dy));
    return core.Square(nearest.col, nearest.row);
  }
}

class _GoStonesPainter extends CustomPainter {
  final List<List<int>> stones;
  final GoBoardGeometry geometry;
  final (int, int)? lastMove;
  final Set<(int, int)> hints;
  final (int, int)? selected;

  _GoStonesPainter({
    required this.stones,
    required this.geometry,
    this.lastMove,
    this.hints = const {},
    this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stoneRadius = geometry.pitch * 0.4;

    for (var row = 0; row < geometry.boardSize; row++) {
      for (var col = 0; col < geometry.boardSize; col++) {
        final stone = stones[row][col];
        if (stone == 0) continue;
        final center = geometry.intersectionOffset(row, col);
        canvas.drawCircle(
          center,
          stoneRadius,
          Paint()..color = stone == 1 ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F0),
        );
        canvas.drawCircle(
          center,
          stoneRadius,
          Paint()
            ..color = const Color(0x33000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    for (final (row, col) in hints) {
      canvas.drawCircle(
        geometry.intersectionOffset(row, col),
        geometry.pitch * 0.12,
        Paint()..color = const Color(0x80FFC107),
      );
    }

    final last = lastMove;
    if (last != null) {
      canvas.drawCircle(
        geometry.intersectionOffset(last.$1, last.$2),
        geometry.pitch * 0.14,
        Paint()
          ..color = const Color(0xFFE53935)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final sel = selected;
    if (sel != null) {
      canvas.drawCircle(
        geometry.intersectionOffset(sel.$1, sel.$2),
        geometry.pitch * 0.3,
        Paint()
          ..color = const Color(0xFF42A5F5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_GoStonesPainter oldDelegate) =>
      oldDelegate.stones != stones ||
      oldDelegate.lastMove != lastMove ||
      oldDelegate.hints != hints ||
      oldDelegate.selected != selected;
}

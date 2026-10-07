import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';

/// Standard hoshi (star point) positions for the common board sizes.
const Map<int, List<(int, int)>> kGoStarPoints = {
  9: [(2, 2), (2, 6), (4, 4), (6, 2), (6, 6)],
  13: [(3, 3), (3, 9), (6, 6), (9, 3), (9, 9)],
  19: [
    (3, 3),
    (3, 9),
    (3, 15),
    (9, 3),
    (9, 9),
    (9, 15),
    (15, 3),
    (15, 9),
    (15, 15),
  ],
};

/// Shared grid + star-point painter for every Go board screen (AI games,
/// PvP, tsume-go, game history, kifu replay, spectating).
///
/// Reads intersection positions from [GoBoardGeometry] — the same class
/// stones, move markers and tap hit-testing use — so the drawn lines can
/// never drift from where a stone actually renders on top of them.
class GoBoardGridPainter extends CustomPainter {
  final int boardSize;
  final Color lineColor;
  final Color? starPointColor;

  GoBoardGridPainter({
    required this.boardSize,
    this.lineColor = AppColors.grey500,
    this.starPointColor = Colors.white60,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = GoBoardGeometry(size: size.width, boardSize: boardSize);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    // The outermost lines are the board's edge: draw them a touch heavier.
    final edgePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8;

    for (int i = 0; i < boardSize; i++) {
      final p = (i == 0 || i == boardSize - 1) ? edgePaint : paint;
      canvas.drawLine(
        geometry.intersectionOffset(i, 0),
        geometry.intersectionOffset(i, boardSize - 1),
        p,
      );
      canvas.drawLine(
        geometry.intersectionOffset(0, i),
        geometry.intersectionOffset(boardSize - 1, i),
        p,
      );
    }

    final starColor = starPointColor;
    final starPositions = kGoStarPoints[boardSize];
    if (starColor != null && starPositions != null) {
      final starPaint = Paint()..color = starColor;
      for (final (row, col) in starPositions) {
        canvas.drawCircle(
          geometry.intersectionOffset(row, col),
          (geometry.pitch * 0.085).clamp(2.0, 4.5),
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GoBoardGridPainter oldDelegate) =>
      oldDelegate.boardSize != boardSize ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.starPointColor != starPointColor;
}

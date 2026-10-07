import 'dart:ui';

/// Single source of truth for mapping a Go board's line intersections to
/// pixel coordinates within a square canvas of side [size], and back.
///
/// Every board widget (grid lines, star points, stones, the last-move
/// marker, the selection marker, tap hit-testing) must derive its
/// positions from this class so they can never drift apart from one
/// another the way they used to when each was computed independently.
class GoBoardGeometry {
  /// Side length, in logical pixels, of the square board area.
  final double size;

  /// Number of intersections per side (9, 13 or 19).
  final int boardSize;

  /// Distance from the canvas edge to the outermost line on each side.
  final double margin;

  /// Distance between two adjacent intersections.
  final double pitch;

  GoBoardGeometry({required this.size, required this.boardSize})
    : assert(boardSize > 1),
      margin = size / (2 * boardSize),
      pitch = size / boardSize;

  /// Pixel offset of intersection (row, col), with (0, 0) at the top-left
  /// line and (boardSize - 1, boardSize - 1) at the bottom-right line.
  Offset intersectionOffset(int row, int col) =>
      Offset(margin + col * pitch, margin + row * pitch);

  /// The intersection nearest to [localPosition] (rounded, not floored, so
  /// a tap anywhere within half a pitch of a line lands on it).
  ({int row, int col}) nearestIntersection(Offset localPosition) {
    final col = ((localPosition.dx - margin) / pitch).round().clamp(
      0,
      boardSize - 1,
    );
    final row = ((localPosition.dy - margin) / pitch).round().clamp(
      0,
      boardSize - 1,
    );
    return (row: row, col: col);
  }
}

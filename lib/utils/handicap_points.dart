/// Standard (Japanese-style) handicap stone placements for Go.
///
/// Row/col are 0-indexed board coordinates. The star points used follow
/// the conventional real-board layout: edge stars sit 3 lines in from the
/// border on 13x13/19x19 boards, 2 lines in on 9x9.
library;

int _handicapEdge(int boardSize) => boardSize <= 9 ? 2 : 3;

/// Returns the placements for a `count`-stone handicap on a `boardSize`
/// board, in the traditional order (corners, then center, then sides,
/// then center again) so any prefix of the list is itself a valid smaller
/// handicap. `count` below 2 returns an empty list (no handicap).
List<({int row, int col})> handicapPoints(int boardSize, int count) {
  if (count < 2) return const [];

  final edge = _handicapEdge(boardSize);
  final far = boardSize - 1 - edge;
  final center = boardSize ~/ 2;

  final topLeft = (row: edge, col: edge);
  final topRight = (row: edge, col: far);
  final bottomLeft = (row: far, col: edge);
  final bottomRight = (row: far, col: far);
  final centerPoint = (row: center, col: center);
  final left = (row: center, col: edge);
  final right = (row: center, col: far);
  final top = (row: edge, col: center);
  final bottom = (row: far, col: center);

  final points = <({int row, int col})>[topRight, bottomLeft];
  if (count >= 3) points.add(bottomRight);
  if (count >= 4) points.add(topLeft);
  if (count == 5) return [...points, centerPoint];
  if (count >= 6) points.addAll([left, right]);
  if (count == 7) return [...points, centerPoint];
  if (count >= 8) points.addAll([top, bottom]);
  if (count >= 9) points.add(centerPoint);

  return points;
}

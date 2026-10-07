import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';

void main() {
  group('GoBoardGeometry', () {
    for (final boardSize in [9, 13, 19]) {
      test(
        'intersection -> pixel -> nearest intersection round-trips for '
        '${boardSize}x$boardSize',
        () {
          final geometry = GoBoardGeometry(size: 300, boardSize: boardSize);

          for (int row = 0; row < boardSize; row++) {
            for (int col = 0; col < boardSize; col++) {
              final pixel = geometry.intersectionOffset(row, col);
              final nearest = geometry.nearestIntersection(pixel);
              expect(nearest.row, row, reason: 'row mismatch at ($row,$col)');
              expect(nearest.col, col, reason: 'col mismatch at ($row,$col)');
            }
          }
        },
      );
    }

    test('every intersection lies strictly inside the canvas', () {
      const size = 300.0;
      for (final boardSize in [9, 13, 19]) {
        final geometry = GoBoardGeometry(size: size, boardSize: boardSize);
        for (int row = 0; row < boardSize; row++) {
          for (int col = 0; col < boardSize; col++) {
            final offset = geometry.intersectionOffset(row, col);
            expect(offset.dx, inInclusiveRange(0, size));
            expect(offset.dy, inInclusiveRange(0, size));
          }
        }
      }
    });

    test('adjacent intersections are spaced one pitch apart', () {
      final geometry = GoBoardGeometry(size: 300, boardSize: 9);
      final a = geometry.intersectionOffset(0, 0);
      final b = geometry.intersectionOffset(0, 1);
      expect(b.dx - a.dx, closeTo(geometry.pitch, 1e-9));
    });

    test('a tap near the edge still resolves to the nearest border line', () {
      final geometry = GoBoardGeometry(size: 300, boardSize: 9);
      final nearest = geometry.nearestIntersection(const Offset(1, 1));
      expect(nearest, (row: 0, col: 0));

      final farCorner = geometry.nearestIntersection(const Offset(299, 299));
      expect(farCorner, (row: 8, col: 8));
    });

    test('a tap exactly halfway between two lines rounds to one side', () {
      final geometry = GoBoardGeometry(size: 300, boardSize: 9);
      final midpointX =
          (geometry.intersectionOffset(0, 0).dx +
              geometry.intersectionOffset(0, 1).dx) /
          2;
      final nearest = geometry.nearestIntersection(
        Offset(midpointX, geometry.margin),
      );
      expect(nearest.row, 0);
      expect(nearest.col, anyOf(0, 1));
    });
  });
}

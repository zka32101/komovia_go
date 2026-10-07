import 'dart:collection';

/// Result of successfully applying a move to a Go board.
class GoMoveResult {
  final List<List<int>> stones;
  final int capturedCount;
  final int? koRow;
  final int? koCol;

  GoMoveResult({
    required this.stones,
    required this.capturedCount,
    this.koRow,
    this.koCol,
  });
}

/// Pure Go rules engine: connected-group liberties, captures, suicide
/// prevention, and simple (positional) ko enforcement.
///
/// Stones are represented as 0=empty, 1=black, 2=white.
class GoRules {
  GoRules._();

  static Iterable<(int, int)> _neighbors(int row, int col, int boardSize) sync* {
    if (row > 0) yield (row - 1, col);
    if (row < boardSize - 1) yield (row + 1, col);
    if (col > 0) yield (row, col - 1);
    if (col < boardSize - 1) yield (row, col + 1);
  }

  /// Returns the connected group of same-colored stones starting at (row, col).
  static Set<(int, int)> _group(
    List<List<int>> stones,
    int boardSize,
    int row,
    int col,
  ) {
    final color = stones[row][col];
    final visited = <(int, int)>{(row, col)};
    final queue = Queue<(int, int)>()..add((row, col));

    while (queue.isNotEmpty) {
      final (r, c) = queue.removeFirst();
      for (final (nr, nc) in _neighbors(r, c, boardSize)) {
        if (stones[nr][nc] == color && visited.add((nr, nc))) {
          queue.add((nr, nc));
        }
      }
    }
    return visited;
  }

  /// Public wrapper around [_group] for callers outside this file that need
  /// the connected same-colored group at a point (e.g. dead-stone marking,
  /// where tapping one stone should toggle its whole chain). Returns an
  /// empty set if (row, col) is empty.
  static Set<(int, int)> groupAt(
    List<List<int>> stones,
    int boardSize,
    int row,
    int col,
  ) {
    if (stones[row][col] == 0) return const {};
    return _group(stones, boardSize, row, col);
  }

  /// Number of liberties of the group containing the stone at (row, col),
  /// or 0 if the point is empty.
  static int libertiesAt(
    List<List<int>> stones,
    int boardSize,
    int row,
    int col,
  ) {
    if (stones[row][col] == 0) return 0;
    return _liberties(stones, boardSize, _group(stones, boardSize, row, col));
  }

  /// Number of distinct empty liberties adjacent to the group.
  static int _liberties(
    List<List<int>> stones,
    int boardSize,
    Set<(int, int)> group,
  ) {
    final liberties = <(int, int)>{};
    for (final (r, c) in group) {
      for (final (nr, nc) in _neighbors(r, c, boardSize)) {
        if (stones[nr][nc] == 0) {
          liberties.add((nr, nc));
        }
      }
    }
    return liberties.length;
  }

  /// Attempts to play [player] (1=black, 2=white) at (row, col).
  ///
  /// Returns null when the move is illegal: out of bounds, the point is
  /// occupied, the move is self-capture (suicide), or it violates the
  /// simple ko rule (immediate recapture at [koRow]/[koCol]).
  ///
  /// On success, returns the resulting board with opponent captures
  /// removed, the number of stones captured, and the new ko point (if
  /// this move created one).
  static GoMoveResult? applyMove({
    required List<List<int>> stones,
    required int boardSize,
    required int row,
    required int col,
    required int player,
    int? koRow,
    int? koCol,
  }) {
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) {
      return null;
    }
    if (stones[row][col] != 0) {
      return null;
    }
    if (koRow == row && koCol == col) {
      return null;
    }

    final opponent = player == 1 ? 2 : 1;

    final newStones = [
      for (final r in stones) [...r],
    ];
    newStones[row][col] = player;

    var capturedCount = 0;
    final capturedPoints = <(int, int)>[];
    final checkedGroups = <(int, int)>{};

    for (final (nr, nc) in _neighbors(row, col, boardSize)) {
      if (newStones[nr][nc] != opponent || checkedGroups.contains((nr, nc))) {
        continue;
      }
      final group = _group(newStones, boardSize, nr, nc);
      checkedGroups.addAll(group);

      if (_liberties(newStones, boardSize, group) == 0) {
        for (final (gr, gc) in group) {
          newStones[gr][gc] = 0;
          capturedPoints.add((gr, gc));
        }
        capturedCount += group.length;
      }
    }

    // Suicide check: the played group must have a liberty once opponent
    // captures have been resolved.
    final ownGroup = _group(newStones, boardSize, row, col);
    if (_liberties(newStones, boardSize, ownGroup) == 0) {
      return null;
    }

    // Simple ko: a single-stone capture that also came from a single-stone
    // placement forbids the opponent from immediately recapturing there.
    int? nextKoRow;
    int? nextKoCol;
    if (capturedCount == 1 && ownGroup.length == 1) {
      nextKoRow = capturedPoints.first.$1;
      nextKoCol = capturedPoints.first.$2;
    }

    return GoMoveResult(
      stones: newStones,
      capturedCount: capturedCount,
      koRow: nextKoRow,
      koCol: nextKoCol,
    );
  }

  /// Non-mutating legality check, for UI pre-validation.
  static bool isLegalMove({
    required List<List<int>> stones,
    required int boardSize,
    required int row,
    required int col,
    required int player,
    int? koRow,
    int? koCol,
  }) {
    return applyMove(
          stones: stones,
          boardSize: boardSize,
          row: row,
          col: col,
          player: player,
          koRow: koRow,
          koCol: koCol,
        ) !=
        null;
  }
}

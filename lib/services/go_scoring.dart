import 'dart:collection';

/// Chinese-rules area score for one color: stones on the board this color
/// owns plus the empty territory it fully surrounds.
class AreaScore {
  final double blackScore;
  final double whiteScore;

  const AreaScore({required this.blackScore, required this.whiteScore});

  /// null on an exact tie. With [komi] applied this is only possible if a
  /// caller passes a non-default komi of 0.
  String? winnerUid({required String blackUid, required String whiteUid}) {
    if (blackScore == whiteScore) return null;
    return blackScore > whiteScore ? blackUid : whiteUid;
  }
}

/// Chinese-rules area scoring, shared by FuegoEngineService (AI games) and
/// PvpGameService (PvP games) so both count territory the same way instead
/// of PvP using a separate, less accurate stones-only estimate.
///
/// This method itself does NOT attempt dead-stone detection — it scores
/// whatever board it's given. FuegoEngineService's own judgeGameEnd gets an
/// automatic dead-stone guess from the native Fuego library's safety solver
/// only when that's bundled (most builds don't have it), and PvP games have
/// no engine in the loop at all. For the common case where no engine
/// resolves it automatically, callers are expected to run a manual
/// dead-stone-marking step first (see [withDeadStonesRemoved] and
/// `DeadStoneMarkingScreen`) and pass the result in here, the same way
/// every other Go server (OGS/KGS/Tygem) resolves life & death at game end.
class GoScoring {
  GoScoring._();

  static const double defaultKomi = 3.75;

  /// Returns a copy of [stones] with every point in [deadPoints] cleared to
  /// empty (0), so [computeAreaScore] counts them as the opponent's
  /// territory instead of the owner's living stones.
  static List<List<int>> withDeadStonesRemoved(
    List<List<int>> stones,
    Iterable<(int, int)> deadPoints,
  ) {
    if (deadPoints.isEmpty) return stones;
    final copy = [for (final row in stones) [...row]];
    for (final (row, col) in deadPoints) {
      copy[row][col] = 0;
    }
    return copy;
  }

  static AreaScore computeAreaScore(
    List<List<int>> stones,
    int boardSize, {
    double komi = defaultKomi,
  }) {
    int blackStones = 0;
    int whiteStones = 0;
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (stones[row][col] == 1) {
          blackStones++;
        } else if (stones[row][col] == 2) {
          whiteStones++;
        }
      }
    }

    final visited = List.generate(boardSize, (_) => List.filled(boardSize, false));
    int blackTerritory = 0;
    int whiteTerritory = 0;

    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (stones[row][col] == 0 && !visited[row][col]) {
          final territory = _evaluateTerritory(stones, visited, row, col, boardSize);
          if (territory.owner == 1) {
            blackTerritory += territory.count;
          } else if (territory.owner == 2) {
            whiteTerritory += territory.count;
          }
        }
      }
    }

    return AreaScore(
      blackScore: blackStones.toDouble() + blackTerritory.toDouble(),
      whiteScore: whiteStones.toDouble() + whiteTerritory.toDouble() + komi,
    );
  }

  /// Flood-fills one connected empty region. Returns owner 1 (black) or 2
  /// (white) only if every stone bordering the region belongs to that one
  /// color; owner 0 (neutral dame) otherwise.
  static ({int owner, int count}) _evaluateTerritory(
    List<List<int>> stones,
    List<List<bool>> visited,
    int startRow,
    int startCol,
    int boardSize,
  ) {
    final queue = Queue<(int, int)>();
    queue.add((startRow, startCol));
    visited[startRow][startCol] = true;

    int emptyCount = 0;
    final adjacentOwners = <int>{};

    while (queue.isNotEmpty) {
      final (row, col) = queue.removeFirst();
      emptyCount++;

      final neighbors = [
        (row - 1, col),
        (row + 1, col),
        (row, col - 1),
        (row, col + 1),
      ];

      for (final (nextRow, nextCol) in neighbors) {
        if (nextRow < 0 || nextRow >= boardSize || nextCol < 0 || nextCol >= boardSize) {
          continue;
        }

        final cell = stones[nextRow][nextCol];
        if (cell == 0) {
          if (!visited[nextRow][nextCol]) {
            visited[nextRow][nextCol] = true;
            queue.add((nextRow, nextCol));
          }
        } else {
          adjacentOwners.add(cell);
        }
      }
    }

    if (adjacentOwners.length == 1) {
      return (owner: adjacentOwners.first, count: emptyCount);
    }
    return (owner: 0, count: 0);
  }
}

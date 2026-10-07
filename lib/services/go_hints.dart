import 'go_rules.dart';

/// 初心者向けの「石の危険」ヒントを盤面から計算する（純Dart）。
///
/// - アタリ: 呼吸点が1つしかない群の石。次に相手が打つと取られる。
/// - 打てない点: 自殺手・コウで打てない空点。
class GoHints {
  GoHints._();

  /// 呼吸点が1つの群に属する石の座標と、その色(1=黒, 2=白)。
  static Map<(int, int), int> atariStones(
    List<List<int>> stones,
    int boardSize,
  ) {
    final result = <(int, int), int>{};
    final seen = <(int, int)>{};
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final color = stones[r][c];
        if (color == 0 || seen.contains((r, c))) continue;
        final group = GoRules.groupAt(stones, boardSize, r, c);
        seen.addAll(group);
        if (GoRules.libertiesAt(stones, boardSize, r, c) == 1) {
          for (final p in group) {
            result[p] = color;
          }
        }
      }
    }
    return result;
  }

  /// [player] が打てない空点（自殺手・コウ）。
  static Set<(int, int)> illegalPoints(
    List<List<int>> stones,
    int boardSize,
    int player, {
    int? koRow,
    int? koCol,
  }) {
    final result = <(int, int)>{};
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (stones[r][c] != 0) continue;
        final ok = GoRules.isLegalMove(
          stones: stones,
          boardSize: boardSize,
          row: r,
          col: c,
          player: player,
          koRow: koRow,
          koCol: koCol,
        );
        if (!ok) result.add((r, c));
      }
    }
    return result;
  }
}

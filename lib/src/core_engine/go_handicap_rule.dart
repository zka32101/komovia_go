import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/utils/handicap_points.dart';

import 'go_position.dart';

/// Go's 置き石 (handicap stones), wrapping the app's existing
/// `handicapPoints` (`utils/handicap_points.dart`) — the exact placement
/// `startNewGameProvider` already uses to pre-place black stones on the
/// standard star points for a handicap game.
///
/// Unlike shogi's 駒落ち (always 下手/[Side.first] moving first — see
/// `ShogiHandicapRule`'s doc comment), [apply] sets white to move first,
/// per [HandicapRule.apply]'s own doc comment on go's convention — and
/// matching `startNewGameProvider`'s `isBlackTurn: handicapStones < 2`.
class GoHandicapRule implements HandicapRule<GoPosition> {
  @override
  final String id;

  @override
  final String label;

  final int stoneCount;

  const GoHandicapRule._(this.id, this.label, this.stoneCount);

  static const two = GoHandicapRule._('2-stone', '二子局', 2);
  static const three = GoHandicapRule._('3-stone', '三子局', 3);
  static const four = GoHandicapRule._('4-stone', '四子局', 4);
  static const five = GoHandicapRule._('5-stone', '五子局', 5);
  static const six = GoHandicapRule._('6-stone', '六子局', 6);
  static const seven = GoHandicapRule._('7-stone', '七子局', 7);
  static const eight = GoHandicapRule._('8-stone', '八子局', 8);
  static const nine = GoHandicapRule._('9-stone', '九子局', 9);

  /// Every supported handicap, in increasing order of stones placed.
  static const all = [two, three, four, five, six, seven, eight, nine];

  @override
  GoPosition apply(GoPosition standardInitialPosition) {
    final board = standardInitialPosition.boardState;
    final stones = [for (final row in board.stones) [...row]];
    for (final point in handicapPoints(board.boardSize, stoneCount)) {
      stones[point.row][point.col] = 1; // black
    }
    return standardInitialPosition.copyWith(
      boardState: board.copyWith(stones: stones, isBlackTurn: false),
    );
  }
}

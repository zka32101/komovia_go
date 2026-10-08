import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/board_state.dart';

/// Go's [Position]: komovia_go's existing [BoardState] (board, captures,
/// whose turn, ko point), plus the two pieces of end-of-game state
/// [BoardState] itself doesn't carry (the app tracks them separately, as
/// `consecutivePassesProvider`/a plain `GameResult.resignation` value in
/// `game_provider.dart`, not on the board snapshot) — mirroring
/// `ShogiPosition`'s `resignedBy` field, which is likewise bolted on
/// rather than part of the wrapped representation.
///
/// Side mapping: black moves first in Go, exactly like 先手 in shogi, so
/// [Side.first] = black, [Side.second] = white — `boardState.isBlackTurn`
/// is simply `sideToMove == Side.first`.
class GoPosition extends Position {
  final BoardState boardState;

  /// Number of passes played back-to-back (reset to 0 by any stone
  /// placement). Two in a row ends the game — see [GoGame.result] in
  /// `go_game.dart`. Mirrors `consecutivePassesProvider`.
  final int consecutivePasses;

  /// Set once a side resigns; null while the game continues normally.
  final Side? resignedBy;

  const GoPosition({
    required this.boardState,
    this.consecutivePasses = 0,
    this.resignedBy,
  });

  @override
  Side get sideToMove => boardState.isBlackTurn ? Side.first : Side.second;

  GoPosition copyWith({
    BoardState? boardState,
    int? consecutivePasses,
    Side? resignedBy,
  }) {
    return GoPosition(
      boardState: boardState ?? this.boardState,
      consecutivePasses: consecutivePasses ?? this.consecutivePasses,
      resignedBy: resignedBy ?? this.resignedBy,
    );
  }

  @override
  String toString() =>
      'GoPosition(size: ${boardState.boardSize}, sideToMove: $sideToMove, '
      'passes: $consecutivePasses, resignedBy: $resignedBy)';
}

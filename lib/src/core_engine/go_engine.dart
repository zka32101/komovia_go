import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/services/fuego_engine_service.dart';

import 'go_game.dart';
import 'go_position.dart';

/// Go's `Engine<GoPosition>`, wrapping `FuegoEngineService` — the native
/// Fuego engine when bundled, falling back to `DartGoEngine` (a pure-Dart
/// flat Monte Carlo search) otherwise. Both paths are already
/// interchangeable behind one Dart API in `FuegoEngineService` itself,
/// which is exactly the on-device/server-backed interchangeability
/// `Engine`'s own doc comment anticipates.
///
/// `FuegoEngineService.requestAiMove`'s `isPlayerBlack` parameter names
/// the *human*'s color, not the color it should move for — the app only
/// ever calls it with `isPlayerBlack: true` (human is always black) and
/// relies on the engine computing for the other color. [bestMove] inverts
/// that mapping so it can request a move for either
/// `position.sideToMove`: `isPlayerBlack: position.sideToMove ==
/// Side.second` (i.e. "the human is black" exactly when we want the
/// engine to answer as white).
class GoEngine implements Engine<GoPosition> {
  final FuegoEngineService _fuego;

  GoEngine([FuegoEngineService? fuego]) : _fuego = fuego ?? FuegoEngineService();

  /// No separate downloadable model/evaluation data — both the native
  /// Fuego build and the `DartGoEngine` fallback are compiled in, like
  /// komovia_shogi's hand-tuned evaluation.
  @override
  String get modelVersion => 'builtin';

  /// [timeBudget] is not supported by `FuegoEngineService.requestAiMove`
  /// (it only takes a 1-10 `aiLevel`) and is ignored, same as the
  /// interface's own "if given" wording allows.
  @override
  Future<Move?> bestMove(
    GoPosition position, {
    required int level,
    Duration? timeBudget,
  }) async {
    final board = position.boardState;
    final aiMove = await _fuego.requestAiMove(
      boardSize: board.boardSize,
      stones: board.stones,
      isPlayerBlack: position.sideToMove == Side.second,
      aiLevel: level.clamp(1, 10),
      movesCount: 0,
      koRow: board.koRow,
      koCol: board.koCol,
    );
    if (aiMove.isPass) return const PassMove();
    return DropMove(
      pieceType: GoGame.stonePieceType,
      to: Square(aiMove.col, aiMove.row),
    );
  }

  /// `FuegoEngineService.evaluatePosition`'s `scoreDiff`
  /// (`blackScore - whiteScore`) is already fixed to black's perspective
  /// — i.e. [Side.first]'s, matching this method's contract exactly with
  /// no sign flip needed.
  @override
  Future<double> evaluate(GoPosition position) async {
    final board = position.boardState;
    final evaluation = await _fuego.evaluatePosition(
      stones: board.stones,
      boardSize: board.boardSize,
    );
    return evaluation.scoreDiff;
  }

  /// No life-and-death / forced-win solver exists yet in komovia_go (the
  /// native Fuego build only exposes a dead-stone *scoring* heuristic via
  /// `suggestDeadStones`, not a forced-capture search, and
  /// `DartGoEngine`'s Monte Carlo search has no mate-search equivalent
  /// either) — see `Engine.findForcedWin`'s own doc comment, which
  /// explicitly defers go/chess's exact semantics until their packages
  /// are built. Always returning null is a conservative, honest
  /// implementation of the documented contract ("null... does not mean
  /// none exists"), not a placeholder pretending to search.
  @override
  Future<Move?> findForcedWin(GoPosition position, {required int maxPly}) async {
    return null;
  }
}

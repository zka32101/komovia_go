/// Go's implementation of komovia_core's `Game`/`Engine`/`BoardRenderer`/
/// `HandicapRule`/puzzle-conversion interfaces, adapting komovia_go's
/// existing Go rules (`GoRules`), AI (`FuegoEngineService`), scoring
/// (`GoScoring`), handicap placement (`handicapPoints`) and board
/// rendering primitives (`GoBoardGeometry`/`GoBoardGridPainter`) —
/// mirroring komovia_shogi's `komovia_shogi.dart` barrel for shogi.
///
/// This is an adapter layer only: komovia_go's actual rules/AI/rendering
/// code is unchanged. Nothing in the app imports this yet — it exists so
/// Go can be treated the same way shogi already is through
/// `komovia_core`'s generic interfaces (a shared matching/rating service,
/// a cross-game puzzle-of-the-day, ...), none of which is built here.
library;

export 'src/core_engine/go_board_renderer.dart';
export 'src/core_engine/go_engine.dart';
export 'src/core_engine/go_game.dart';
export 'src/core_engine/go_handicap_rule.dart';
export 'src/core_engine/go_position.dart';
export 'src/core_engine/go_puzzle.dart';

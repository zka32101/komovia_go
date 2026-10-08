import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/board_state.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';
import 'package:komovia_go/utils/handicap_points.dart';
import 'package:komovia_go/utils/sgf_parser.dart';

import 'go_position.dart';

/// Go, implementing komovia_core's [Game] over the app's existing rules
/// engine (`GoRules`, pure liberties/capture/ko logic in `go_rules.dart`),
/// Chinese-rules area scoring (`go_scoring.dart`), handicap placement
/// (`handicap_points.dart`), and real move-order SGF
/// (`utils/sgf_parser.dart`'s `generateSgfFromMoves`/`parseSgfMoves` —
/// distinct from `BoardState.toSgf()`/`fromSgf()`, which is the app's own
/// final-snapshot-only dialect used by [encode]/[decode] below, exactly
/// the same "position snapshot" vs. "move-by-move kifu" split
/// `Game.encode`'s doc comment describes).
///
/// The only Go [Move] kind used is [DropMove] (placing a stone — see
/// `move.dart`'s own doc comment: "a stone onto an empty point (go)") and
/// [PassMove]/[ResignMove]; Go has no [BoardMove] (stones are placed, not
/// moved once on the board).
class GoGame implements Game<GoPosition> {
  /// The only [DropMove.pieceType] Go ever uses — there is only one kind
  /// of stone, unlike shogi's per-piece-type drops.
  static const stonePieceType = 'stone';

  @override
  String get id => 'go';

  /// [options] recognizes `'boardSize'` (default 9, matching
  /// `BoardState.empty`'s own default) and `'handicapStones'` (default 0;
  /// placement + turn order mirrors `startNewGameProvider`'s own
  /// convention — see [GoHandicapRule] in `go_handicap_rule.dart` for the
  /// same logic exposed as a reusable [HandicapRule]).
  @override
  GoPosition initialPosition({Map<String, Object?> options = const {}}) {
    final boardSize = options['boardSize'] as int? ?? 9;
    final handicapStones = options['handicapStones'] as int? ?? 0;

    final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
    for (final point in handicapPoints(boardSize, handicapStones)) {
      stones[point.row][point.col] = 1; // black
    }

    return GoPosition(
      boardState: BoardState(
        boardSize: boardSize,
        stones: stones,
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: handicapStones < 2,
      ),
    );
  }

  /// A cheap string key: board contents + whose turn + the simple-ko
  /// point. Deliberately not delegated to [encode] (unlike shogi, which
  /// can because SFEN already carries everything needed) — `toSgf()`
  /// only captures stone placement, not turn/ko, both of which matter for
  /// "is this really the same position" here.
  @override
  Object positionKey(GoPosition position) {
    final board = position.boardState;
    final buffer = StringBuffer()..write(board.boardSize)..write(':');
    for (final row in board.stones) {
      for (final value in row) {
        buffer.write(value);
      }
    }
    buffer
      ..write(':')
      ..write(board.isBlackTurn ? 1 : 0)
      ..write(':')
      ..write(board.koRow)
      ..write(',')
      ..write(board.koCol);
    return buffer.toString();
  }

  /// Go only needs *simple* ko (the ko point stored on [GoPosition] via
  /// [BoardState.koRow]/[koCol]), not full positional superko — see
  /// `GoRules.applyMove`'s own doc comment, and `Game.legalMoves`'s doc
  /// comment, which calls this combination out by name as a case that
  /// doesn't need [historyKeys]. Accepted for interface conformance but
  /// otherwise unused.
  @override
  List<Move> legalMoves(
    GoPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (!result(position, historyKeys: historyKeys).isOngoing) return const [];

    final board = position.boardState;
    final player = board.isBlackTurn ? 1 : 2;
    final moves = <Move>[];

    for (var row = 0; row < board.boardSize; row++) {
      for (var col = 0; col < board.boardSize; col++) {
        if (GoRules.isLegalMove(
          stones: board.stones,
          boardSize: board.boardSize,
          row: row,
          col: col,
          player: player,
          koRow: board.koRow,
          koCol: board.koCol,
        )) {
          moves.add(DropMove(pieceType: stonePieceType, to: Square(col, row)));
        }
      }
    }
    // Passing is always available in Go, unlike shogi/chess.
    moves.add(const PassMove());
    return moves;
  }

  @override
  GoPosition apply(
    GoPosition position,
    Move move, {
    List<Object> historyKeys = const [],
  }) {
    final board = position.boardState;
    switch (move) {
      case DropMove(pieceType: final pieceType, to: final to):
        if (pieceType != stonePieceType) {
          throw ArgumentError('Unknown drop piece type "$pieceType" for go: $move');
        }
        final player = board.isBlackTurn ? 1 : 2;
        final result = GoRules.applyMove(
          stones: board.stones,
          boardSize: board.boardSize,
          row: to.rank,
          col: to.file,
          player: player,
          koRow: board.koRow,
          koCol: board.koCol,
        );
        if (result == null) {
          throw ArgumentError('Illegal move $move on $position');
        }
        final newBoard = board.copyWith(
          stones: result.stones,
          capturedBlack: player == 2 ? board.capturedBlack + result.capturedCount : null,
          capturedWhite: player == 1 ? board.capturedWhite + result.capturedCount : null,
          isBlackTurn: !board.isBlackTurn,
          lastMoveRow: to.rank,
          lastMoveCol: to.file,
          koRow: result.koRow,
          koCol: result.koCol,
        );
        return position.copyWith(boardState: newBoard, consecutivePasses: 0);

      case PassMove():
        final newBoard = board.copyWith(
          isBlackTurn: !board.isBlackTurn,
          koRow: null,
          koCol: null,
        );
        return position.copyWith(
          boardState: newBoard,
          consecutivePasses: position.consecutivePasses + 1,
        );

      case ResignMove(side: final side):
        return position.copyWith(resignedBy: side);

      case BoardMove():
        throw ArgumentError(
          'Go has no board-move: stones are placed (DropMove), never moved once on the board: $move',
        );
    }
  }

  /// Scoring after two consecutive passes uses [GoScoring.computeAreaScore]
  /// directly on the raw board — i.e. every stone counts as alive, same
  /// as `PvpGameService`'s current fallback (see `go_scoring.dart`'s own
  /// class comment). `FuegoEngineService.judgeGameEnd`'s richer path
  /// (native dead-stone detection, or the app's manual
  /// `DeadStoneMarkingScreen`) is a UI-level step built on top of this,
  /// not part of the core rules engine's synchronous [result].
  @override
  GameResult result(
    GoPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (position.resignedBy != null) {
      return GameResult.win(position.resignedBy!.opponent, WinReason.resignation);
    }

    if (position.consecutivePasses >= 2) {
      final board = position.boardState;
      final score = GoScoring.computeAreaScore(board.stones, board.boardSize);
      if (score.blackScore == score.whiteScore) {
        return const GameResult.draw(WinReason.score);
      }
      return GameResult.win(
        score.blackScore > score.whiteScore ? Side.first : Side.second,
        WinReason.score,
      );
    }

    return GameResult.ongoing;
  }

  /// A single-position snapshot — stone placement + board size only, via
  /// `BoardState.toSgf()`/`fromSgf()` (the app's own dialect: `B[col,row]`
  /// comma-separated coordinates, no move order, no turn/captures/ko).
  /// Real move-by-move SGF is [exportRecord]/[importRecord]'s job.
  @override
  String encode(GoPosition position) => position.boardState.toSgf();

  @override
  GoPosition decode(String notation) {
    if (!notation.contains('SZ[') || !notation.trimLeft().startsWith('(;')) {
      throw FormatException('Not a recognizable Go position snapshot: $notation');
    }
    return GoPosition(boardState: BoardState.fromSgf(notation));
  }

  /// Real move-by-move SGF, via `sgf_parser.dart`'s `generateSgfFromMoves`
  /// (the same dialect `KifuLibrary`'s curated games and saved
  /// `GameRecord.sgfData` use), plus an `RE[...]` result property — not
  /// produced by `generateSgfFromMoves` itself, since nothing in the app
  /// needed it before (a saved game's `GameResult` lives in its own
  /// Firestore field, not inside the SGF string) — added here purely so
  /// [importRecord] can round-trip [GameResult] through this one string,
  /// the way a real SGF file would.
  @override
  String exportRecord(GameRecord record) {
    final moves = <({int row, int col, String player})>[];
    for (final recorded in record.moves) {
      final player = recorded.side == Side.first ? 'black' : 'white';
      switch (recorded.move) {
        case DropMove(pieceType: final pieceType, to: final to):
          if (pieceType != stonePieceType) {
            throw ArgumentError('Unknown drop piece type "$pieceType" to export: $recorded');
          }
          moves.add((row: to.rank, col: to.file, player: player));
        case PassMove():
          moves.add((row: -1, col: -1, player: player));
        case BoardMove():
        case ResignMove():
          throw ArgumentError('Unsupported move to export for go: $recorded');
      }
    }

    final boardSize = int.tryParse(record.metadata['boardSize'] ?? '') ??
        (record.initialPositionNotation != null
            ? decode(record.initialPositionNotation!).boardState.boardSize
            : 9);

    final sgf = generateSgfFromMoves(moves, boardSize);
    final re = _reProperty(record.result);
    if (re == null) return sgf;
    // sgf always ends in a single closing ')' (see generateSgfFromMoves).
    return '${sgf.substring(0, sgf.length - 1)}RE[$re])';
  }

  static String? _reProperty(GameResult result) {
    switch (result.kind) {
      case ResultKind.ongoing:
        return null;
      case ResultKind.draw:
        return 'Draw';
      case ResultKind.win:
        final color = result.winner == Side.first ? 'B' : 'W';
        final reason = result.reason == WinReason.resignation ? 'Resign' : 'Score';
        return '$color+$reason';
    }
  }

  static final _rePattern = RegExp(r'RE\[([^\]]*)\]');
  static final _reWinPattern = RegExp(r'^([BW])\+(.+)$');

  @override
  GameRecord importRecord(String notation) {
    if (!notation.contains('SZ[') || !notation.trimLeft().startsWith('(;')) {
      throw FormatException('Not a recognizable SGF game record: $notation');
    }

    final boardSize = parseSgfBoardSize(notation);
    final sgfMoves = parseSgfMoves(notation);

    var pos = initialPosition(options: {'boardSize': boardSize});
    final moves = <RecordedMove>[];
    for (var i = 0; i < sgfMoves.length; i++) {
      final sgfMove = sgfMoves[i];
      final side = sgfMove.player == 1 ? Side.first : Side.second;
      final move = sgfMove.isPass
          ? const PassMove()
          : DropMove(pieceType: stonePieceType, to: Square(sgfMove.col, sgfMove.row));
      moves.add(RecordedMove(number: i + 1, side: side, move: move));
      // Also validates the move is actually legal against the replayed
      // position, not just well-formed notation.
      pos = apply(pos, move);
    }

    final reMatch = _rePattern.firstMatch(notation);
    final result = reMatch != null ? _parseReProperty(reMatch.group(1)!) : this.result(pos);

    return GameRecord(
      gameId: id,
      moves: moves,
      result: result,
      metadata: {'boardSize': boardSize.toString()},
    );
  }

  static GameResult _parseReProperty(String re) {
    if (re == 'Draw' || re == '0') return const GameResult.draw(WinReason.score);
    final match = _reWinPattern.firstMatch(re);
    if (match == null) return GameResult.ongoing;
    final winner = match.group(1) == 'B' ? Side.first : Side.second;
    final reasonText = match.group(2)!.toLowerCase();
    final reason = reasonText.startsWith('resign') ? WinReason.resignation : WinReason.score;
    return GameResult.win(winner, reason);
  }
}

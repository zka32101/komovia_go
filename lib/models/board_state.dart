/// Sentinel used by [BoardState.copyWith] to distinguish "argument omitted"
/// from "explicitly set to null" for nullable fields.
const Object _unset = Object();

/// Represents the state of a Go board
class BoardState {
  /// Board size (9, 13, or 19)
  final int boardSize;
  /// 2D grid of stones: 0=empty, 1=black, 2=white
  final List<List<int>> stones;
  /// Number of captured black stones
  final int capturedBlack;
  /// Number of captured white stones
  final int capturedWhite;
  /// Whether it's black's turn
  final bool isBlackTurn;
  /// Last move position (row)
  final int? lastMoveRow;
  /// Last move position (col)
  final int? lastMoveCol;
  /// Point forbidden by the simple ko rule for the next move (row)
  final int? koRow;
  /// Point forbidden by the simple ko rule for the next move (col)
  final int? koCol;

  const BoardState({
    required this.boardSize,
    required this.stones,
    required this.capturedBlack,
    required this.capturedWhite,
    required this.isBlackTurn,
    this.lastMoveRow,
    this.lastMoveCol,
    this.koRow,
    this.koCol,
  });

  /// Create an empty board
  factory BoardState.empty({int size = 9}) {
    return BoardState(
      boardSize: size,
      stones: List.generate(size, (_) => List.filled(size, 0)),
      capturedBlack: 0,
      capturedWhite: 0,
      isBlackTurn: true,
    );
  }

  /// Create a copy with optional overrides.
  ///
  /// Nullable fields accept an explicit `null` to clear them (as opposed to
  /// omitting the argument, which keeps the current value).
  BoardState copyWith({
    int? boardSize,
    List<List<int>>? stones,
    int? capturedBlack,
    int? capturedWhite,
    bool? isBlackTurn,
    Object? lastMoveRow = _unset,
    Object? lastMoveCol = _unset,
    Object? koRow = _unset,
    Object? koCol = _unset,
  }) {
    return BoardState(
      boardSize: boardSize ?? this.boardSize,
      stones: stones ?? this.stones,
      capturedBlack: capturedBlack ?? this.capturedBlack,
      capturedWhite: capturedWhite ?? this.capturedWhite,
      isBlackTurn: isBlackTurn ?? this.isBlackTurn,
      lastMoveRow:
          identical(lastMoveRow, _unset) ? this.lastMoveRow : lastMoveRow as int?,
      lastMoveCol:
          identical(lastMoveCol, _unset) ? this.lastMoveCol : lastMoveCol as int?,
      koRow: identical(koRow, _unset) ? this.koRow : koRow as int?,
      koCol: identical(koCol, _unset) ? this.koCol : koCol as int?,
    );
  }

  /// Parse the app's own SGF dialect (as written by [toSgf]: `SZ[n]`
  /// plus `;B[col,row]`/`;W[col,row]` per stone) into a starting position.
  /// Used to load a tsume-go problem's initial setup.
  factory BoardState.fromSgf(String sgf) {
    final sizeMatch = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
    final boardSize = sizeMatch != null ? int.parse(sizeMatch.group(1)!) : 9;

    final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));

    final moveMatches = RegExp(r'([BW])\[([a-zA-Z]),([a-zA-Z])\]').allMatches(sgf);
    for (final match in moveMatches) {
      final col = _sgfCharToCoord(match.group(2)!);
      final row = _sgfCharToCoord(match.group(3)!);
      if (row >= 0 && row < boardSize && col >= 0 && col < boardSize) {
        stones[row][col] = match.group(1) == 'B' ? 1 : 2;
      }
    }

    return BoardState(
      boardSize: boardSize,
      stones: stones,
      capturedBlack: 0,
      capturedWhite: 0,
      isBlackTurn: true,
    );
  }

  static int _sgfCharToCoord(String ch) {
    final code = ch.codeUnitAt(0);
    if (code >= 97 && code <= 122) return code - 97; // a-z
    return 26 + (code - 65); // A-Z
  }

  /// Convert to SGF (Standard Game Format) for engine
  String toSgf() {
    final buffer = StringBuffer();
    buffer.write('(;GM[1]SZ[$boardSize]');

    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        if (stones[row][col] != 0) {
          final stoneType = stones[row][col] == 1 ? 'B' : 'W';
          buffer.write(';$stoneType[${_coordToSgf(col)},${_coordToSgf(row)}]');
        }
      }
    }
    buffer.write(')');
    return buffer.toString();
  }

  String _coordToSgf(int coord) {
    // SGF coordinates: 'a'-'z' (0-25), then 'A'-'Z' (26-51), covering
    // every board size Go is actually played on (up to 25x25/52-point SGF).
    if (coord < 26) {
      return String.fromCharCode(97 + coord);
    }
    return String.fromCharCode(65 + (coord - 26));
  }
}

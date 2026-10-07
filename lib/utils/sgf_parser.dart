/// 標準的なSGF棋譜（本譜のみ、分岐は考慮しない）から、盤サイズと着手の
/// 並びを取り出す軽量パーサー。
///
/// `BoardState.fromSgf`（models/board_state.dart）が扱うのは、このアプリが
/// 自己対局を保存するときに使う「最終局面のみのスナップショット方言」
/// （`B[col,row]` のようにカンマ区切り、着手順を持たない）で、
/// これとは別物。こちらはKifuLibrary（棋譜ライブラリ）が持つ本物のSGF
/// （`B[qd]` のように2文字の連続した座標、着手順そのもの）を読むためのもの。
library sgf_parser;

import 'package:komovia_go/services/go_rules.dart';

class SgfMove {
  final int row;
  final int col;
  final int player; // 1 = black, 2 = white
  final bool isPass;

  const SgfMove({
    required this.row,
    required this.col,
    required this.player,
    this.isPass = false,
  });
}

/// `SZ[n]`から盤サイズを読み取る。見つからなければ19路盤とみなす。
int parseSgfBoardSize(String sgf) {
  final match = RegExp(r'SZ\[(\d+)\]').firstMatch(sgf);
  return match != null ? int.parse(match.group(1)!) : 19;
}

/// 本譜の着手列を、出現順のまま返す。
///
/// プロパティは `;` で始まるノードの中に連続して書かれる
/// （例: `;GM[1]SZ[19]PB[...]PW[...]`）ため、`;B[...]`/`;W[...]` は
/// 手番ノードの先頭にしか現れない。分岐(`(...)(...)`)は主分岐だけを
/// 素直に前から読む単純化をしている。
List<SgfMove> parseSgfMoves(String sgf) {
  final moves = <SgfMove>[];
  final matches = RegExp(r';([BW])\[([a-tA-T]{0,2})\]').allMatches(sgf);
  for (final match in matches) {
    final player = match.group(1) == 'B' ? 1 : 2;
    final coord = match.group(2)!;
    if (coord.isEmpty) {
      moves.add(SgfMove(row: -1, col: -1, player: player, isPass: true));
      continue;
    }
    final col = _sgfCharToCoord(coord[0]);
    final row = _sgfCharToCoord(coord[1]);
    moves.add(SgfMove(row: row, col: col, player: player));
  }
  return moves;
}

int _sgfCharToCoord(String ch) {
  final code = ch.codeUnitAt(0);
  if (code >= 97 && code <= 122) return code - 97; // a-z
  return 26 + (code - 65); // A-Z
}

String _coordToSgfChar(int coord) {
  if (coord < 26) return String.fromCharCode(97 + coord); // a-z
  return String.fromCharCode(65 + (coord - 26)); // A-Z
}

/// `moveHistoryProvider`が保持する実際の着手列から、本物の連続SGF
/// （`;B[xx];W[yy]...`、着手順そのもの）を生成する。KifuLibraryの本物の
/// SGFと同じ方言なので、[parseSgfMoves]/[replaySgfMoves]でそのまま
/// 読み戻せる — `BoardState.toSgf()`（最終局面のみのスナップショット
/// 方言、分岐/着手順を持たない）とは別物。
String generateSgfFromMoves(
  List<({int row, int col, String player})> moves,
  int boardSize,
) {
  final buffer = StringBuffer('(;GM[1]FF[4]SZ[$boardSize]');
  for (final move in moves) {
    final color = move.player == 'black' ? 'B' : 'W';
    if (move.row < 0 || move.col < 0) {
      buffer.write(';$color[]'); // pass (matches parseSgfMoves' empty-coord check)
      continue;
    }
    buffer.write(';$color[${_coordToSgfChar(move.col)}${_coordToSgfChar(move.row)}]');
  }
  buffer.write(')');
  return buffer.toString();
}

/// `moves`の先頭から`upToIndex`手目まで（`upToIndex`件）を、GoRulesで捕獲を
/// 反映しながら再生し、盤面を返す。着手がその局面で非合法（棋譜の記録揺れ等）
/// になった場合は、その手だけ無視してそのまま次の手に進む
/// （観戦・学習用の再生なので、1手打てなくても再生全体を止めない）。
List<List<int>> replaySgfMoves(
  List<SgfMove> moves,
  int boardSize,
  int upToIndex,
) {
  var stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
  int? koRow;
  int? koCol;

  final count = upToIndex.clamp(0, moves.length);
  for (var i = 0; i < count; i++) {
    final move = moves[i];
    if (move.isPass) continue;
    if (move.row < 0 || move.row >= boardSize || move.col < 0 || move.col >= boardSize) {
      continue;
    }
    final result = GoRules.applyMove(
      stones: stones,
      boardSize: boardSize,
      row: move.row,
      col: move.col,
      player: move.player,
      koRow: koRow,
      koCol: koCol,
    );
    if (result == null) continue;
    stones = result.stones;
    koRow = result.koRow;
    koCol = result.koCol;
  }
  return stones;
}

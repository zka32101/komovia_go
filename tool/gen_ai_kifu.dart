// Generates self-play 9x9 games with the in-app Dart engine and writes
// scripts/seed/kifu_library.json (upload with scripts/seed_firestore.py).
// Run: dart run tool/gen_ai_kifu.dart
import 'dart:convert';
import 'dart:io';

import 'package:goen/services/dart_go_engine.dart';
import 'package:goen/services/go_rules.dart';
import 'package:goen/services/go_scoring.dart';

const size = 9;
// (black level, white level, difficulty label shown to the user)
const pairings = [
  (2, 2, 1), (3, 3, 1), (4, 4, 2), (5, 5, 2),
  (6, 6, 3), (7, 7, 3), (8, 8, 4), (9, 9, 4), (10, 10, 5), (10, 8, 5),
];

String c(int v) => String.fromCharCode(97 + v);

void main() {
  final out = <String, Map<String, dynamic>>{};
  var n = 0;
  for (final (bl, wl, diff) in pairings) {
    n++;
    var stones = List.generate(size, (_) => List.filled(size, 0));
    int? koR, koC;
    var player = 1, passes = 0;
    final sgf = StringBuffer('(;GM[1]FF[4]SZ[$size]KM[3.75]PB[GoEn AI Lv$bl]PW[GoEn AI Lv$wl]');
    final body = StringBuffer();
    var moves = 0;
    while (passes < 2 && moves < 140) {
      final flat = [for (final r in stones) ...r];
      final m = DartGoEngine.chooseMoveSync(
        board: flat,
        size: size,
        player: player,
        level: player == 1 ? bl : wl,
        koIndex: koR == null ? -1 : koR * size + koC!,
        seed: n * 1000 + moves,
        budgetMs: 150,
        maxPlayouts: 400,
      );
      final col = player == 1 ? 'B' : 'W';
      GoMoveResult? res;
      if (m != null) {
        res = GoRules.applyMove(
            stones: stones, boardSize: size, row: m.$1, col: m.$2,
            player: player, koRow: koR, koCol: koC);
      }
      if (m == null || res == null) {
        body.write(';$col[]');
        passes++;
        koR = koC = null;
      } else {
        body.write(';$col[${c(m.$2)}${c(m.$1)}]');
        stones = res.stones;
        koR = res.koRow;
        koC = res.koCol;
        passes = 0;
      }
      player = 3 - player;
      moves++;
    }
    final s = GoScoring.computeAreaScore(stones, size);
    final diffPts = (s.blackScore - s.whiteScore).abs();
    final re = s.blackScore > s.whiteScore ? 'B+$diffPts' : 'W+$diffPts';
    sgf.write('RE[$re]');
    sgf.write(body);
    sgf.write(')');
    final id = 'ai_selfplay_${n.toString().padLeft(2, '0')}';
    out[id] = {
      'title': 'AI対局 9路盤 Lv$bl vs Lv$wl',
      'blackPlayer': 'GoEn AI Lv$bl',
      'whitePlayer': 'GoEn AI Lv$wl',
      'sgfData': sgf.toString(),
      'category': 'copyright_free',
      'isPremium': false,
      'source': 'GoEn内蔵AI同士の自己対局（オリジナル生成・著作権フリー）',
      'difficulty': diff,
    };
    stdout.writeln('$id moves=$moves $re');
  }
  File('scripts/seed/kifu_library.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(out));
}

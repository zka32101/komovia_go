// 碁のルール実装(GoRules)を、独立に書いた単純な参照実装と、ランダム対局で突き合わせる。
// 石の取り方・自殺手・単純コウの判定が全局面で一致することを確認する。
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/dart_go_engine.dart';
import 'package:komovia_go/services/go_rules.dart';

/// 参照実装。戻り値 null=違法。
List<List<int>>? refApply(List<List<int>> b, int n, int r, int c, int me, (int, int)? ko) {
  if (b[r][c] != 0) return null;
  if (ko != null && ko.$1 == r && ko.$2 == c) return null;
  final nb = [for (final row in b) [...row]];
  nb[r][c] = me;
  final opp = 3 - me;
  Set<int> group(int sr, int sc) {
    final color = nb[sr][sc];
    final seen = <int>{sr * n + sc};
    final stack = [sr * n + sc];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final pr = p ~/ n, pc = p % n;
      for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final qr = pr + d.$1, qc = pc + d.$2;
        if (qr < 0 || qc < 0 || qr >= n || qc >= n) continue;
        if (nb[qr][qc] == color && seen.add(qr * n + qc)) stack.add(qr * n + qc);
      }
    }
    return seen;
  }

  bool hasLiberty(Set<int> g) {
    for (final p in g) {
      final pr = p ~/ n, pc = p % n;
      for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final qr = pr + d.$1, qc = pc + d.$2;
        if (qr < 0 || qc < 0 || qr >= n || qc >= n) continue;
        if (nb[qr][qc] == 0) return true;
      }
    }
    return false;
  }

  // 相手の全ての群を調べ、呼吸点が無ければ取る（打った石の隣だけでなく盤全体で確認）
  final done = <int>{};
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      if (nb[i][j] != opp || done.contains(i * n + j)) continue;
      final g = group(i, j);
      done.addAll(g);
      if (!hasLiberty(g)) {
        for (final p in g) {
          nb[p ~/ n][p % n] = 0;
        }
      }
    }
  }
  if (!hasLiberty(group(r, c))) return null; // 自殺手
  return nb;
}

String show(List<List<int>> b) => b.map((r) => r.map((v) => '.XO'[v]).join()).join('\n');

void main() {
  test('GoRules は参照実装と全てのランダム局面で一致する（9路・13路）', () {
    final rng = Random(20261004);
    for (final n in [9, 13]) {
      for (var game = 0; game < 120; game++) {
        var b = List.generate(n, (_) => List.filled(n, 0));
        var me = 1;
        (int, int)? ko;
        for (var mv = 0; mv < 220; mv++) {
          final r = rng.nextInt(n), c = rng.nextInt(n);
          final expected = refApply(b, n, r, c, me, ko);
          final actual = GoRules.applyMove(
            stones: b, boardSize: n, row: r, col: c, player: me,
            koRow: ko?.$1, koCol: ko?.$2,
          );
          if (expected == null) {
            expect(actual, isNull, reason: 'n=$n game=$game mv=$mv ($r,$c) player=$me は違法のはず\n${show(b)}');
            continue;
          }
          expect(actual, isNotNull, reason: 'n=$n game=$game mv=$mv ($r,$c) player=$me は合法のはず\n${show(b)}');
          expect(show(actual!.stones), show(expected),
              reason: 'n=$n game=$game mv=$mv ($r,$c) player=$me 盤面が不一致\n前:\n${show(b)}');
          b = actual.stones;
          ko = actual.koRow == null ? null : (actual.koRow!, actual.koCol!);
          me = 3 - me;
        }
      }
    }
  });

  test('AIエンジンが選ぶ手は常に合法（GoRulesで検証）', () {
    final rng = Random(7);
    for (var game = 0; game < 6; game++) {
      const n = 9;
      var b = List.generate(n, (_) => List.filled(n, 0));
      var me = 1;
      (int, int)? ko;
      for (var mv = 0; mv < 70; mv++) {
        final flat = [for (final row in b) ...row];
        final pick = DartGoEngine.chooseMoveSync(
          board: flat, size: n, player: me, level: 1 + rng.nextInt(3),
          koIndex: ko == null ? -1 : ko.$1 * n + ko.$2,
          seed: rng.nextInt(1 << 30), maxPlayouts: 40, budgetMs: 40,
        );
        if (pick == null) { me = 3 - me; ko = null; continue; }
        final res = GoRules.applyMove(
          stones: b, boardSize: n, row: pick.$1, col: pick.$2, player: me,
          koRow: ko?.$1, koCol: ko?.$2,
        );
        expect(res, isNotNull, reason: 'AIが違法手 (${pick.$1},${pick.$2}) を選んだ game=$game mv=$mv\n${show(b)}');
        b = res!.stones;
        ko = res.koRow == null ? null : (res.koRow!, res.koCol!);
        me = 3 - me;
      }
    }
  });
}

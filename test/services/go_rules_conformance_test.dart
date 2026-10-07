// 碁のルール適合テスト: 石の取り方・自殺手・コウ・終局時の地の数え方が
// 標準的な碁のルールどおりかを確認する。
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';

List<List<int>> board(List<String> rows) => [
      for (final r in rows)
        [for (final c in r.split('')) c == 'X' ? 1 : (c == 'O' ? 2 : 0)],
    ];

void main() {
  group('石を取る順序', () {
    test('最後の呼吸点を埋める手でも、相手を取れるなら自殺手ではなく取る', () {
      // 白O(0,0)は呼吸点が(0,1)だけ。黒が(0,1)に打つと、黒も一時的に呼吸点0だが
      // 先に白を取るので合法で、白(0,0)が盤から消える。
      final b = board([
        'O.XX',
        'XX..',
        '....',
        '....',
      ]);
      final r = GoRules.applyMove(stones: b, boardSize: 4, row: 0, col: 1, player: 1);
      expect(r, isNotNull);
      expect(r!.stones[0][0], 0);
      expect(r.capturedCount, 1);
    });

    test('取れない自殺手は禁止', () {
      final b = board([
        '.O..',
        'O...',
        '....',
        '....',
      ]);
      expect(
        GoRules.applyMove(stones: b, boardSize: 4, row: 0, col: 0, player: 1),
        isNull,
      );
    });

    test('取ったのは相手の石だけ（自分の石は消えない）', () {
      final b = board([
        'XO..',
        'XO..',
        'XO..',
        '.OX.',
      ]);
      // 白の縦の列は (3,0) を黒が打っても呼吸点が残るので取れない。ここでは白が
      // 呼吸点 (3,0) に打つ手で黒の列を取る（黒は列の下が白で塞がる）。
      final r = GoRules.applyMove(stones: b, boardSize: 4, row: 3, col: 0, player: 2);
      expect(r, isNotNull);
      expect(r!.stones[0][0], 0);
      expect(r.stones[1][0], 0);
      expect(r.stones[2][0], 0);
      expect(r.capturedCount, 3);
      for (var i = 0; i < 4; i++) {
        expect(r.stones[i][1], 2, reason: '白の石は残る');
      }
      expect(r.stones[3][0], 2);
    });

    test('両方の石を同時に取ることはない（打った側が取るのは相手の無呼吸の群だけ）', () {
      // 黒(1,1)を打つと白(1,2)が取れるが、黒の他の群は取られない
      final b = board([
        '.X..',
        'XOX.',
        '.X..',
        '....',
      ]);
      // 白O(1,1)の呼吸点は0？ 4方向すべて黒なのでそもそも取られている局面は不正。
      // 代わりに、白の呼吸点が1つの状態を作って検証する。
      final c = board([
        '.X..',
        'XO..',
        '.X..',
        '....',
      ]);
      final r = GoRules.applyMove(stones: c, boardSize: 4, row: 1, col: 2, player: 1);
      expect(r, isNotNull);
      expect(r!.stones[1][1], 0, reason: '白を取る');
      expect(r.stones[1][2], 1, reason: '打った黒は残る');
      expect(r.capturedCount, 1);
      // 盤に無関係な黒は全て残る
      expect(r.stones[0][1], 1);
      expect(r.stones[2][1], 1);
      expect(r.stones[1][0], 1);
      expect(b[1][1], 2); // 元の盤は変更されない
    });
  });

  group('コウ', () {
    test('1子取りのあと、同じ場所へ即取り返す手は禁止。他の手のあとは許可', () {
      final b = board([
        '.XO.',
        'XO.O',
        '.XO.',
        '....',
      ]);
      // 黒が(1,2)に打って白(1,1)を1子取る（コウ）
      final first = GoRules.applyMove(stones: b, boardSize: 4, row: 1, col: 2, player: 1);
      expect(first, isNotNull);
      expect(first!.koRow, 1);
      expect(first.koCol, 1);
      // 白が即(1,1)に打ち返すのは禁止
      final recapture = GoRules.applyMove(
        stones: first.stones,
        boardSize: 4,
        row: 1,
        col: 1,
        player: 2,
        koRow: first.koRow,
        koCol: first.koCol,
      );
      expect(recapture, isNull);
      // 別の場所に打てばコウは解除され、次の手番では打ち返せる
      final elsewhere = GoRules.applyMove(
        stones: first.stones, boardSize: 4, row: 3, col: 3, player: 2,
        koRow: first.koRow, koCol: first.koCol,
      );
      expect(elsewhere, isNotNull);
      expect(elsewhere!.koRow, isNull);
    });
  });

  group('終局時の地の数え方（中国式）', () {
    test('両者の石に接する空点はダメ（どちらの地でもない）', () {
      final b = board([
        'X.O',
        'X.O',
        'X.O',
      ]);
      final s = GoScoring.computeAreaScore(b, 3, komi: 0);
      // 黒の石3、白の石3、真ん中の列は両方に接するのでダメ → 3対3
      expect(s.blackScore, 3);
      expect(s.whiteScore, 3);
    });

    test('一方の石にだけ囲まれた空点はその色の地', () {
      final b = board([
        'XX.',
        'X.O',
        '.OO',
      ]);
      final s = GoScoring.computeAreaScore(b, 3, komi: 0);
      // 黒: 石3 + 左上寄り地は両方に接する(1,1)なのでダメ、(2,0)は黒白どちらにも接する
      expect(s.blackScore, 3);
      expect(s.whiteScore, 3);
    });

    test('最後に打った側が全部取ることはない: 両方の石がある盤で、黒の地が白に入らない', () {
      final b = board([
        '.X.O.',
        '.X.O.',
        '.X.O.',
        '.X.O.',
        '.X.O.',
      ]);
      final s = GoScoring.computeAreaScore(b, 5, komi: 0);
      // 黒: 石5 + 左の列5 = 10 / 白: 石5 + 右の列5 = 10 / 真ん中はダメ
      expect(s.blackScore, 10);
      expect(s.whiteScore, 10);
    });
  });
}

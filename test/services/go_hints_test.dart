import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/go_hints.dart';

List<List<int>> board(List<String> rows) => [
      for (final r in rows)
        [for (final c in r.split('')) c == 'X' ? 1 : (c == 'O' ? 2 : 0)],
    ];

void main() {
  test('呼吸点が1つの群だけがアタリ（群の全ての石に印が付く）', () {
    final b = board([
      'XO..',
      'XO..',
      '.X..',
      '....',
    ]);
    // 白の2子(0,1),(1,1): 呼吸点は (0,2),(1,2) の2つ → アタリではない
    // 黒の2子(0,0),(1,0): 呼吸点は (2,0) だけ → アタリ
    final atari = GoHints.atariStones(b, 4);
    expect(atari[(0, 0)], 1);
    expect(atari[(1, 0)], 1);
    expect(atari.containsKey((0, 1)), isFalse);
    expect(atari.containsKey((2, 1)), isFalse);
  });

  test('呼吸点が2つ以上ならアタリではない', () {
    final b = board([
      '.X..',
      '....',
      '....',
      '....',
    ]);
    expect(GoHints.atariStones(b, 4), isEmpty);
  });

  test('相手の石を取れる点は打てない点に含めない／自殺手は含める', () {
    final b = board([
      '.O..',
      'O...',
      '....',
      '....',
    ]);
    // 黒が(0,0)に打つのは取れない自殺手 → 打てない
    expect(GoHints.illegalPoints(b, 4, 1).contains((0, 0)), isTrue);
    final c = board([
      'OX..',
      'XO..',
      '....',
      '....',
    ]);
    // 白(0,0)は黒に囲まれて(0,0)の呼吸点0... ここでは白が(1,1)にいて(0,0)を打つ手は
    // 黒(0,1),(1,0)を取れるか: 黒(0,1)の呼吸点は(0,2)があるので取れず、自殺手になる
    expect(GoHints.illegalPoints(c, 4, 2).contains((2, 2)), isFalse);
  });

  test('コウで打てない点が含まれる', () {
    final b = board([
      '.XO.',
      'XO.O',
      '.XO.',
      '....',
    ]);
    final illegal = GoHints.illegalPoints(b, 4, 1, koRow: 1, koCol: 2);
    expect(illegal.contains((1, 2)), isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/go_hints.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/views/widgets/go_hint_painter.dart';

void main() {
  testWidgets('アタリと打てない点の描画が例外なく動く', (tester) async {
    final stones = [
      [1, 2, 0, 0, 0],
      [1, 2, 0, 0, 0],
      [0, 1, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ];
    final geometry = GoBoardGeometry(size: 300, boardSize: 5);
    final painter = GoHintPainter(
      geometry: geometry,
      atari: GoHints.atariStones(stones, 5),
      illegal: GoHints.illegalPoints(stones, 5, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 300, height: 300, child: CustomPaint(painter: painter)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(painter.atari.containsKey((0, 0)), isTrue); // 黒の2子(0,0),(1,0)はアタリ
  });
}

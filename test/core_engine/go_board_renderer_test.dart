import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/komovia_go_engine.dart';

void main() {
  testWidgets('GoBoardRenderer builds a square board and squareAt maps taps back',
      (tester) async {
    final game = GoGame();
    final pos = game.initialPosition(options: {'boardSize': 9});
    final renderer = GoBoardRenderer();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 180,
          child: renderer.build(pos),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);

    final square = renderer.squareAt(
      const BoardOffset(90, 90),
      const BoardSize(180, 180),
      pos,
    );
    expect(square, isNotNull);
    expect(square!.file, inInclusiveRange(0, 8));
    expect(square.rank, inInclusiveRange(0, 8));

    expect(
      renderer.squareAt(const BoardOffset(-10, -10), const BoardSize(180, 180), pos),
      isNull,
    );
  });
}

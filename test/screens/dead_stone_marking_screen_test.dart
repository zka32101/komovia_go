import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/views/screens/dead_stone_marking_screen.dart';

import '../test_utils.dart';

void main() {
  group('DeadStoneMarkingScreen', () {
    List<List<int>> buildBoard() {
      final stones = List.generate(9, (_) => List.filled(9, 0));
      stones[0][0] = 1; // black group (connected)
      stones[0][1] = 1;
      stones[3][3] = 2; // isolated white stone
      return stones;
    }

    Offset intersectionOffset(
      WidgetTester tester,
      Finder boardFinder,
      int boardSize,
      int row,
      int col,
    ) {
      final topLeft = tester.getTopLeft(boardFinder);
      final size = tester.getSize(boardFinder);
      final margin = size.width / (2 * boardSize);
      final pitch = size.width / boardSize;
      return topLeft + Offset(margin + col * pitch, margin + row * pitch);
    }

    testWidgets('renders all stones with none marked dead initially',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            onConfirm: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('黒: 2.0'), findsOneWidget);
      // White's score includes the default 3.75 komi.
      expect(find.text('白: 4.8'), findsOneWidget);
    });

    testWidgets('tapping one stone marks its whole connected group dead',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            onConfirm: (_) {},
          ),
        ),
      );
      await tester.pump();

      final boardFinder = find.byType(GestureDetector).first;
      await tester.tapAt(intersectionOffset(tester, boardFinder, 9, 0, 0));
      await tester.pump();

      // Both stones of the connected black group toggle together, and the
      // isolated white stone (not part of that group) stays untouched.
      expect(find.byIcon(Icons.close), findsNWidgets(2));
    });

    testWidgets('tapping a dead group again revives it', (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            onConfirm: (_) {},
          ),
        ),
      );
      await tester.pump();

      final boardFinder = find.byType(GestureDetector).first;
      final tapOffset = intersectionOffset(tester, boardFinder, 9, 0, 0);

      await tester.tapAt(tapOffset);
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tapAt(tapOffset);
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('黒: 2.0'), findsOneWidget);
    });

    testWidgets('reset button clears all dead marks', (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            onConfirm: (_) {},
          ),
        ),
      );
      await tester.pump();

      final boardFinder = find.byType(GestureDetector).first;
      await tester.tapAt(intersectionOffset(tester, boardFinder, 9, 0, 0));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.text('リセット'));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('黒: 2.0'), findsOneWidget);
    });

    testWidgets('confirm button reports exactly the marked dead points',
        (tester) async {
      Set<(int, int)>? confirmed;

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            onConfirm: (deadPoints) => confirmed = deadPoints,
          ),
        ),
      );
      await tester.pump();

      final boardFinder = find.byType(GestureDetector).first;
      // Mark the isolated white stone as dead; leave the black group alive.
      await tester.tapAt(intersectionOffset(tester, boardFinder, 9, 3, 3));
      await tester.pump();

      await tester.tap(find.text('この地合で確定する'));
      await tester.pump();

      expect(confirmed, {(3, 3)});
    });

    testWidgets('pre-seeded suggestedDeadPoints start marked dead',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: DeadStoneMarkingScreen(
            stones: buildBoard(),
            boardSize: 9,
            suggestedDeadPoints: const {(3, 3)},
            onConfirm: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}

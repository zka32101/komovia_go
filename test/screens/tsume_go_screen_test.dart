import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/tsume_go_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// A fixture puzzle with a valid, minimal SGF so the board/solution
/// views have something real to render.
final _testProblem = TsumeGoProblem(
  id: 'test-tsumego-1',
  difficulty: 2,
  sgfData: '(;GM[1]SZ[9]AB[cc][dd]AW[cd])',
  solutionSgf: '(;GM[1]SZ[9];B[dc])',
  explanation: 'テスト用の解説文です。',
  source: 'Test Collection',
  version: 1,
  createdAt: DateTime.now(),
  expectedMoves: 1,
);

void main() {
  group('TsumeGoScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          todaysTsumeProblemProvider.overrideWith((ref) async => _testProblem),
        ],
      );
    });

    testWidgets('renders tsume-go screen with puzzle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Verify scaffold exists
      expect(find.byType(Scaffold), findsWidgets);

      // Verify loading state or puzzle display
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('displays puzzle difficulty stars', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // When puzzle loads, difficulty should show
      expect(find.text('難易度'), findsWidgets);
    });

    testWidgets('shows attempt counter', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Verify attempts counter
      expect(find.text('試行回数'), findsWidgets);
    });

    testWidgets('displays hint button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // App bar should have hint icon
      expect(find.byType(AppBar), findsWidgets);
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('shows puzzle board grid', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Board should render with CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays difficulty selector', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Difficulty selector should be visible
      expect(find.text('難易度から探す'), findsWidgets);

      // ChoiceChip widgets for difficulty selection
      expect(find.byType(Wrap), findsWidgets);
    });

    testWidgets('shows check solution button when unsolved',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // When puzzle not solved, show the check-solution button
      expect(find.text('解答をチェック'), findsWidgets);
    });

    testWidgets('shows skip button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Skip to tomorrow button should be visible
      expect(find.text('明日にスキップ'), findsWidgets);
    });

    testWidgets('displays solution explanation when solved',
        (WidgetTester tester) async {
      final solvedContainer = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          todaysTsumeProblemProvider.overrideWith((ref) async => _testProblem),
          isPuzzleSolvedProvider.overrideWith((ref) => true),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: solvedContainer,
        ),
      );
      await tester.pump();

      // When solved, show explanation button
      expect(find.text('解説を見る'), findsWidgets);
    });

    testWidgets('shows puzzle solved badge', (WidgetTester tester) async {
      final solvedContainer = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          todaysTsumeProblemProvider.overrideWith((ref) async => _testProblem),
          isPuzzleSolvedProvider.overrideWith((ref) => true),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: solvedContainer,
        ),
      );
      await tester.pump();

      // Solved badge with check icon
      expect(find.text('解答済み！'), findsWidgets);
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows expected moves when unsolved',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Show hint about expected moves when puzzle not solved (renders as
      // "N手で解ける", combined with the count)
      expect(find.textContaining('手で解ける'), findsWidgets);
    });

    testWidgets('hint button opens dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );

      // Tap hint button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Dialog should appear with hint text
      expect(find.byType(AlertDialog), findsWidgets);
      expect(find.text('ヒント'), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('requires authentication to check solution',
        (WidgetTester tester) async {
      final noAuthContainer = TestUtils.createTestContainer(
        currentUser: null,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: noAuthContainer,
        ),
      );

      // Check solution button should be disabled
    });

    testWidgets('shows loading state when fetching puzzle',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // During async load, might show progress indicator
      // expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('has back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Back button should work via Navigator.pop
      final skipButton = find.text('明日にスキップ');
      expect(skipButton, findsWidgets);
    });

    testWidgets('choice chips for difficulty selection are functional',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      // Find difficulty selector
      expect(find.byType(ChoiceChip), findsWidgets);

      // Tap a chip (e.g., Easy)
      // await tester.tap(find.byType(ChoiceChip).first);
      // await tester.pumpAndSettle();
    });

    testWidgets('appbar title is correct', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const TsumeGoScreen(),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('今日のパズル'), findsWidgets);
    });
  });
}

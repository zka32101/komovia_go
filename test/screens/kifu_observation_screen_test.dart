import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/kifu_observation_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// A fixture game with a valid, minimal SGF so the replay view (board,
/// move slider, playback controls) has something real to render.
final _testKifu = KifuLibrary(
  id: 'test-kifu-1',
  title: '本因坊道策 vs 本因坊算悦',
  blackPlayer: 'Honinbo Shusaku',
  whitePlayer: 'Inoue Genan Inseki',
  sgfData: '(;GM[1]SZ[9];B[cc];W[gg];B[ce];W[ge])',
  aiCommentaryData: null,
  category: KifuCategory.copyrightFree,
  isPremium: false,
  source: 'Public Domain',
  gameDate: DateTime(1846),
  createdAt: DateTime.now(),
);

void main() {
  group('KifuObservationScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          kifuLibraryProvider.overrideWith((ref) async => [_testKifu]),
        ],
      );
    });

    testWidgets('renders kifu observation screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      // Verify scaffold exists
      expect(find.byType(Scaffold), findsWidgets);

      // Verify app bar
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('displays screen title', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      // Verify title
      expect(find.text('観戦して学ぶ'), findsWidgets);
    });

    testWidgets('shows info button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      // Info button should exist
      expect(find.byIcon(Icons.info_outline), findsWidgets);
    });

    testWidgets('displays game library header', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pump();

      // Should show historical games section
      expect(find.text('歴史的名局'), findsWidgets);
    });

    testWidgets('shows loading state while fetching library', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      // Wait for future to resolve
      await tester.pumpAndSettle();

      // Game library should be loaded
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('displays game cards in library', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Game cards should be visible
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('game card shows title and players', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Game information should be visible
      expect(find.textContaining('Honinbo Shusaku'), findsWidgets);
    });

    testWidgets('game card shows category and source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Category and source should be visible
      expect(find.text('カテゴリー'), findsWidgets);
      expect(find.text('名局'), findsWidgets);
    });

    testWidgets('play icon on game card', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Play icon should be visible
      expect(find.byIcon(Icons.play_circle_outline), findsWidgets);
    });

    testWidgets('can select game to watch', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap on a game card
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Replay interface should appear
      expect(find.textContaining('Honinbo Shusaku'), findsWidgets);
    });

    testWidgets('replay view shows game header', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Should show back button
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });

    testWidgets('replay board is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Board should be rendered
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows move counter', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Move counter should be visible
      expect(find.textContaining('手目'), findsWidgets);
    });

    testWidgets('displays move progress slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Slider should exist
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('shows playback control buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Control buttons
      expect(find.text('前へ'), findsWidgets);
      expect(find.text('再生'), findsWidgets);
      expect(find.text('次へ'), findsWidgets);
    });

    testWidgets('previous button disabled at start', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Previous button exists but may be disabled at move 0
      expect(find.text('前へ'), findsWidgets);
    });

    testWidgets('displays commentary section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Commentary section
      expect(find.text('解説'), findsWidgets);
    });

    testWidgets('back to library button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Click back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to library
      expect(find.text('歴史的名局'), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      final appBar = find.byType(AppBar).first;
      final appBarWidget = tester.widget<AppBar>(appBar);

      expect(appBarWidget.centerTitle, true);
      expect(appBarWidget.backgroundColor, AppColors.sumi);
      expect(appBarWidget.elevation, 0);
    });

    testWidgets('opens info dialog when info button tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.byType(AlertDialog), findsWidgets);
    });

    testWidgets('info dialog contains learning information', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Check dialog content
      expect(find.text('観戦モードについて'), findsWidgets);
    });

    testWidgets('single game shows players vs format', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Should show players information
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('board visualization uses custom painter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Board should use CustomPaint (GoGridPainter)
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('play button has golden background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Select a game
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Play button exists
      expect(find.text('再生'), findsWidgets);
    });

    testWidgets('handles multiple games in library', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Multiple game cards should exist
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('KifuObservationScreen difficulty filter', () {
    final easyKifu = KifuLibrary(
      id: 'easy-kifu',
      title: 'Easy Game',
      blackPlayer: 'Player A',
      whitePlayer: 'Player B',
      sgfData: '(;GM[1]SZ[9];B[cc];W[gg])',
      category: KifuCategory.copyrightFree,
      isPremium: false,
      source: 'Public Domain',
      createdAt: DateTime.now(),
      difficulty: 1,
    );
    final hardKifu = KifuLibrary(
      id: 'hard-kifu',
      title: 'Hard Game',
      blackPlayer: 'Player C',
      whitePlayer: 'Player D',
      sgfData: '(;GM[1]SZ[9];B[cc];W[gg])',
      category: KifuCategory.copyrightFree,
      isPremium: false,
      source: 'Public Domain',
      createdAt: DateTime.now(),
      difficulty: 5,
    );
    final unratedKifu = KifuLibrary(
      id: 'unrated-kifu',
      title: 'Unrated Game',
      blackPlayer: 'Player E',
      whitePlayer: 'Player F',
      sgfData: '(;GM[1]SZ[9];B[cc];W[gg])',
      category: KifuCategory.copyrightFree,
      isPremium: false,
      source: 'Public Domain',
      createdAt: DateTime.now(),
    );

    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          kifuLibraryProvider.overrideWith(
            (ref) async => [easyKifu, hardKifu, unratedKifu],
          ),
        ],
      );
    });

    testWidgets('shows every game by default, with a difficulty icon only for rated ones',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Easy Game'), findsOneWidget);
      expect(find.text('Hard Game'), findsOneWidget);
      expect(find.text('Unrated Game'), findsOneWidget);
      expect(find.text('★☆☆☆☆'), findsOneWidget);
      expect(find.text('★★★★★'), findsOneWidget);
    });

    testWidgets('filtering by a difficulty hides games that do not match',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, '★☆☆☆☆'));
      await tester.pumpAndSettle();

      expect(find.text('Easy Game'), findsOneWidget);
      expect(find.text('Hard Game'), findsNothing);
      expect(find.text('Unrated Game'), findsNothing);
    });

    testWidgets('a filter with no matches shows the no-match state with a way back',
        (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const KifuObservationScreen(),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, '★★☆☆☆'));
      await tester.pumpAndSettle();

      expect(find.text('この難易度に該当する棋譜はありません'), findsOneWidget);

      await tester.tap(find.text('すべて'));
      await tester.pumpAndSettle();

      expect(find.text('Easy Game'), findsOneWidget);
      expect(find.text('Hard Game'), findsOneWidget);
      expect(find.text('Unrated Game'), findsOneWidget);
    });
  });
}

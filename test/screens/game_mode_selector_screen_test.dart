import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import '../test_utils.dart';

void main() {
  group('GameModeSelectorScreen Tests', () {
    late ProviderContainer testContainer;

    setUp(() {
      testContainer = TestUtils.createTestContainer();
    });

    /// Test 1: Screen displays loading state initially
    testWidgets('displays loading state while loading game modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: testContainer,
          child: const GameModeSelectorScreen(),
        ),
      );

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ゲームモード読込中...'), findsOneWidget);
    });

    /// Test 2: Screen displays game modes list
    testWidgets('displays list of game modes', (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'blitz_1',
          name: 'ブリッツ',
          description: '5分の高速対局',
          timeLimit: 300,
          difficulty: 'medium',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
        GameMode(
          id: 'correspondence_1',
          name: 'ターンベース',
          description: 'ゆっくりした対局',
          timeLimit: 0,
          difficulty: 'easy',
          type: GameModeType.correspondence,
          maxPlayers: 2,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify modes are displayed
      expect(find.text('ブリッツ'), findsOneWidget);
      expect(find.text('ターンベース'), findsOneWidget);
    });

    /// Test 3: Screen displays empty state when no modes available
    testWidgets('displays empty state when no modes available',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => <GameMode>[]),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify empty state
      expect(find.byIcon(Icons.sports_esports_outlined), findsOneWidget);
      expect(find.text('ゲームモードがありません'), findsOneWidget);
    });

    /// Test 4: Screen displays error state on load failure
    testWidgets('displays error state when loading fails',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async {
            throw 'ネットワークエラー';
          }),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify error state
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('エラーが発生しました'), findsOneWidget);
      expect(find.text('ネットワークエラー'), findsOneWidget);
    });

    /// Test 5: Tapping a game mode selects it
    testWidgets('selects game mode on tap', (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'blitz_1',
          name: 'ブリッツ',
          description: '5分の高速対局',
          timeLimit: 300,
          difficulty: 'medium',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      // Built directly (not via TestUtils.buildTestableWidget) so
      // '/blitz-settings' is a registered route: _selectMode navigates
      // there 300ms after selecting a blitz mode, and letting that timer
      // fire against an unregistered route would throw.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const GameModeSelectorScreen(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/blitz-settings': (_) => const Scaffold(body: Text('stub')),
            },
          ),
        ),
      );
      await tester.pump();

      // Tap on the mode card. blitz navigates to '/blitz-settings'
      // 300ms later (other mode types navigate to their own settings
      // screens, e.g. handicap goes to '/handicap-settings').
      await tester.tap(find.text('ブリッツ'));

      expect(container.read(selectedGameModeProvider)?.id, 'blitz_1');
      expect(container.read(gameModeUIProvider).selectedMode?.id, 'blitz_1');

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('stub'), findsOneWidget);
    });

    /// Test 6: Game modes have correct difficulty badges
    testWidgets('displays correct difficulty badges', (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'easy_1',
          name: '初級モード',
          description: '初心者向け',
          timeLimit: 600,
          difficulty: 'easy',
          type: GameModeType.puzzleRush,
          maxPlayers: 1,
          isActive: true,
        ),
        GameMode(
          id: 'hard_1',
          name: '上級モード',
          description: '上級者向け',
          timeLimit: 300,
          difficulty: 'hard',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify difficulty badges appear
      expect(find.text('初級'), findsOneWidget);
      expect(find.text('上級'), findsOneWidget);
    });

    /// Test 7: Game modes display time limit when present
    testWidgets('displays time limit for modes with time limit',
        (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'blitz_1',
          name: 'ブリッツ',
          description: '5分の高速対局',
          timeLimit: 300,
          difficulty: 'medium',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify time limit is displayed
      expect(find.text('300秒'), findsOneWidget);
    });

    /// Test 8: Game modes display max players
    testWidgets('displays max players for team modes',
        (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'team_1',
          name: 'チーム戦',
          description: '2対2のチーム対局',
          timeLimit: 0,
          difficulty: 'medium',
          type: GameModeType.team,
          maxPlayers: 4,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify max players is displayed
      expect(find.text('最大4人'), findsOneWidget);
    });

    /// Test 9: Back button navigates to previous screen
    testWidgets('back button pops screen', (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'blitz_1',
          name: 'ブリッツ',
          description: '5分の高速対局',
          timeLimit: 300,
          difficulty: 'medium',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify screen is popped (will show snackbar or error)
      // (depends on Navigator context)
    });

    /// Test 10: Different game mode types show correct icons
    testWidgets('displays correct icons for game mode types',
        (WidgetTester tester) async {
      final modes = [
        GameMode(
          id: 'blitz_1',
          name: 'ブリッツ',
          description: '5分の高速対局',
          timeLimit: 300,
          difficulty: 'medium',
          type: GameModeType.blitz,
          maxPlayers: 2,
          isActive: true,
        ),
        GameMode(
          id: 'team_1',
          name: 'チーム戦',
          description: '2対2のチーム対局',
          timeLimit: 0,
          difficulty: 'medium',
          type: GameModeType.team,
          maxPlayers: 4,
          isActive: true,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          activeGameModesProvider.overrideWith((ref) async => modes),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const GameModeSelectorScreen(),
        ),
      );
      await tester.pump();

      // Verify icons appear (lightning for blitz, group for team)
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });
  });
}

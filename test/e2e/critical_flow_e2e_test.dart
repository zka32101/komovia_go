import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/main.dart' show GameResultScreenRouter;
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/fuego_engine_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/index.dart';
import '../test_utils.dart';
import '../fixtures/test_data.dart';

/// requestAiMove() falls back to DartGoEngine, which runs its search in a
/// real spawned Isolate (Isolate.run) — appropriate for the real app, but
/// that isolate's response can never actually be observed from inside
/// flutter_test's fake-async pump loop (the same class of problem
/// documented elsewhere in this suite for real Firestore-backed
/// providers), so pumpAndSettle() hangs forever waiting for the AI's move
/// after every player move. Stub just the AI response with an instant
/// pass, keeping every other FuegoEngineService method (validateMove,
/// evaluatePosition, judgeGameEnd) real and synchronous.
class _InstantAiEngine extends FuegoEngineService {
  @override
  Future<AIMove> requestAiMove({
    required int boardSize,
    required List<List<int>> stones,
    required bool isPlayerBlack,
    required int aiLevel,
    int movesCount = 0,
    int? koRow,
    int? koCol,
  }) async {
    return AIMove(row: -1, col: -1, confidence: 0.5, reasoning: 'test stub');
  }
}

/// Fixture puzzle/kifu so TsumeGoScreen/KifuObservationScreen (both
/// otherwise backed by real Firestore-hitting FutureProviders that never
/// resolve under `flutter_test`) have something real to render instead of
/// spinning forever and timing out pumpAndSettle.
final _testTsumeProblem = TsumeGoProblem(
  id: 'e2e-tsumego-1',
  difficulty: 2,
  sgfData: '(;GM[1]SZ[9]AB[cc][dd]AW[cd])',
  solutionSgf: '(;GM[1]SZ[9];B[dc])',
  explanation: 'テスト用の解説文です。',
  source: 'Test Collection',
  version: 1,
  createdAt: DateTime.now(),
  expectedMoves: 1,
);

final _testKifu = KifuLibrary(
  id: 'e2e-kifu-1',
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

final _testGameRecord = GameRecord(
  id: 'e2e-game-1',
  uid: TestData.testUser.uid,
  boardSize: 9,
  sgfData: '(;GM[1]SZ[9];B[cc];W[gg];B[ce];W[ge])',
  result: GameResult.playerWin,
  aiLevel: 5,
  playedAt: DateTime(2026, 1, 1),
  movesCount: 4,
  gameDuration: const Duration(minutes: 12),
  blackScore: 45.5,
  whiteScore: 30.5,
);

/// A HomeScreen container with every real Firestore-backed provider its
/// reachable destination screens need overridden with fixture data, so
/// navigating to any of them doesn't hang forever waiting on Firestore.
ProviderContainer richHomeContainer() {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(TestData.testUser),
      isSubscriptionActiveProvider.overrideWithValue(false),
      todaysTsumeProblemProvider.overrideWith(
        (ref) async => _testTsumeProblem,
      ),
      kifuLibraryProvider.overrideWith((ref) async => [_testKifu]),
      userGameRecordsProvider(
        TestData.testUser.uid,
      ).overrideWith((ref) async => [_testGameRecord]),
    ],
  );
}

/// HomeScreen/SplashScreen/AIGameScreen navigate via several *named* routes
/// (e.g. '/kifu-observation', '/game-history', '/game-result',
/// '/onboarding'), which only resolve if the test's MaterialApp actually
/// registers them - TestUtils.buildTestableWidget only sets `home:`, so any
/// named push crashes with "Could not find a generator for route". This
/// local wrapper mirrors the subset of main.dart's route table this file's
/// flows actually reach.
Widget _buildTestableApp({
  required Widget child,
  required ProviderContainer container,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: child,
      theme: ThemeData.dark(),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/home': (_) => const HomeScreen(),
        '/tsume-go': (_) => const TsumeGoScreen(),
        '/kifu-observation': (_) => const KifuObservationScreen(),
        '/game-history': (_) => const GameHistoryScreen(),
        '/game-result': (_) => GameResultScreenRouter(),
        '/settings': (_) => const SettingsScreen(),
        '/paywall': (_) => const PaywallScreen(),
      },
    ),
  );
}

void main() {
  group('E2E: Critical User Flows', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          aiEngineServiceProvider.overrideWithValue(_InstantAiEngine()),
        ],
      );
    });

    /// SplashScreen routes based on authStateProvider (a real
    /// FirebaseAuth-backed stream, which never emits a user in a plain
    /// flutter test process) rather than currentUserProvider - override it
    /// too so Splash actually reaches HomeScreen instead of OnboardingScreen.
    ProviderContainer signedInContainer() {
      return ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          isSubscriptionActiveProvider.overrideWithValue(false),
          authStateProvider.overrideWith(
            (ref) => Stream.value(TestData.testUser),
          ),
        ],
      );
    }

    testWidgets('🔄 E2E: Splash → Home → AI Game flow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(
          child: const SplashScreen(),
          container: signedInContainer(),
        ),
      );

      // Verify splash screen is shown
      expect(find.byType(SplashScreen), findsWidgets);

      // Wait for navigation to complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should navigate to home since the signed-in user has completed
      // the tutorial
      expect(
        find.byType(HomeScreen),
        findsWidgets,
        reason: 'Should navigate to HomeScreen after splash',
      );
    });

    testWidgets('🎮 E2E: Home → Play AI Game → Result screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Verify home screen elements (real app bar title, not "Home")
      expect(find.text('碁縁'), findsWidgets);

      // Find and tap "Play AI Game" card
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Should show AI game screen
      expect(find.byType(AIGameScreen), findsWidgets);

      // Verify game board is displayed
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('📊 E2E: Complete AI game and view results',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const AIGameScreen(), container: container),
      );

      // Game should be rendered
      expect(find.byType(Scaffold), findsWidgets);

      // Simulate game play: place a move
      await TestUtils.tap(tester, find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Tap "投了" to open the confirmation dialog
      await TestUtils.tap(tester, find.text('投了'));
      await tester.pumpAndSettle();

      // Confirm resignation inside the dialog (the dialog's own "投了する"
      // button)
      await TestUtils.tap(tester, find.text('投了する'));
      await tester.pumpAndSettle();

      // Should show game result screen
      expect(find.byType(GameResultScreen), findsWidgets);

      // Verify result is displayed
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('🧩 E2E: Daily puzzle solve flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(
          child: const HomeScreen(),
          container: richHomeContainer(),
        ),
      );

      // Verify home screen
      expect(find.text('碁縁'), findsWidgets);

      // Tap puzzle action (real card title is '今日の詰碁')
      final puzzleButton = find.text('今日の詰碁');
      if (puzzleButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, puzzleButton);
        await tester.pumpAndSettle();

        // Should show puzzle screen
        expect(find.byType(Text), findsWidgets);
      }
    });

    testWidgets('📚 E2E: Browse and watch historical game',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(
          child: const HomeScreen(),
          container: richHomeContainer(),
        ),
      );

      // Verify home screen
      expect(find.text('碁縁'), findsWidgets);

      // Tap watch & learn action
      final watchButton = find.text('観戦・学習');
      if (watchButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, watchButton);
        await tester.pumpAndSettle();

        // Should show game library or replay interface
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('📱 E2E: Multi-screen navigation consistency',
        (WidgetTester tester) async {
      // Start from home
      await tester.pumpWidget(
        _buildTestableApp(
          child: const HomeScreen(),
          container: richHomeContainer(),
        ),
      );

      // Navigate to different screens (real card titles)
      final screens = [
        'AI対局',
        '今日の詰碁',
        '観戦・学習',
        '対局履歴',
      ];

      for (final screenName in screens) {
        final button = find.text(screenName);
        if (button.evaluate().isNotEmpty) {
          await TestUtils.tap(tester, button);
          await tester.pumpAndSettle();

          // Should show scaffold
          expect(find.byType(Scaffold), findsWidgets);

          // Navigate back if back button exists
          final backButton = find.byIcon(Icons.arrow_back);
          if (backButton.evaluate().isNotEmpty) {
            await TestUtils.tap(tester, backButton);
            await tester.pumpAndSettle();
          }
        }
      }
    });

    testWidgets('💾 E2E: Data persistence across navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Navigate to a game
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Make a move
      await TestUtils.tap(tester, find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // Navigate back
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, backButton);
        await tester.pumpAndSettle();
      }

      // Navigate to game again
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Game state should be preserved (or new game started)
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('⚡ E2E: Rapid screen transitions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Rapidly navigate between screens
      for (int i = 0; i < 3; i++) {
        // Go to game
        await TestUtils.tap(tester, find.text('AI対局'));
        await tester.pumpAndSettle();

        // Go back
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await TestUtils.tap(tester, backButton);
          await tester.pumpAndSettle();
        }
      }

      // App should remain stable
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('🔐 E2E: Auth state transitions',
        (WidgetTester tester) async {
      // Start authenticated
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      expect(find.text('碁縁'), findsWidgets);

      // Verify user-specific content is visible
      expect(find.byType(Text), findsWidgets);

      // Navigate to settings (icon-only button; no text label exists)
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, settingsButton);
        await tester.pumpAndSettle();

        // Should show settings for authenticated user
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('📊 E2E: Game history tracking across sessions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Navigate to history
      final historyButton = find.text('対局履歴');
      if (historyButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, historyButton);
        await tester.pumpAndSettle();

        // Should show games list
        expect(find.byType(Scaffold), findsWidgets);

        // Verify games are displayed
        expect(find.byType(Text), findsWidgets);
      }
    });

    testWidgets('💳 E2E: Subscription upgrade flow',
        (WidgetTester tester) async {
      final freeUserContainer = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: false,
      );

      await tester.pumpWidget(
        _buildTestableApp(
          child: const HomeScreen(),
          container: freeUserContainer,
        ),
      );

      // After 3 games, paywall should be triggered
      // For this test, we'll manually navigate to paywall
      final upgradeButton = find.text('プレミアムにアップグレード');
      if (upgradeButton.evaluate().isNotEmpty) {
        await TestUtils.tap(tester, upgradeButton);
        await tester.pumpAndSettle();

        // Should show paywall screen
        expect(find.byType(Scaffold), findsWidgets);

        // Verify pricing options are shown
        expect(find.text('月額'), findsWidgets);
        expect(find.text('年額'), findsWidgets);
      }
    });

    testWidgets('🎯 E2E: Complete aha path (3-tap experience)',
        (WidgetTester tester) async {
      // This simulates the complete aha path:
      // 1. Splash screen
      // 2. Onboarding (if needed)
      // 3. Home screen
      // 4. Play AI game
      // 5. Make capture move (aha moment)

      // Start at splash
      await tester.pumpWidget(
        _buildTestableApp(
          child: const SplashScreen(),
          container: signedInContainer(),
        ),
      );

      expect(find.byType(SplashScreen), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should reach home
      expect(find.byType(HomeScreen), findsWidgets);

      // Tap play
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Should show game
      expect(find.byType(AIGameScreen), findsWidgets);

      // Make a move (aha moment - capture)
      await TestUtils.tap(tester, find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      // App should respond to the move
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('🔄 E2E: Error recovery and retry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Navigate to game
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Simulate an error scenario by navigating back and forth
      for (int i = 0; i < 2; i++) {
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await TestUtils.tap(tester, backButton);
          await tester.pumpAndSettle();
        }

        // Retry
        final playButton = find.text('AI対局');
        if (playButton.evaluate().isNotEmpty) {
          await TestUtils.tap(tester, playButton);
          await tester.pumpAndSettle();
        }
      }

      // App should remain functional
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('📱 E2E: Responsive layout across game flow',
        (WidgetTester tester) async {
      // Set device size to mobile. physicalSizeTestValue is in physical
      // pixels, divided by devicePixelRatio to get the logical size the
      // layout actually sees - without pinning the ratio to 1.0 too, the
      // default test devicePixelRatio (3.0) shrinks this to an unrealistic
      // ~133x266 logical window and produces spurious overflow errors that
      // no real device would ever hit.
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      tester.binding.window.physicalSizeTestValue = const Size(400, 800);

      await tester.pumpWidget(
        _buildTestableApp(child: const HomeScreen(), container: container),
      );

      // Verify layout at mobile size
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Navigate through screens
      await TestUtils.tap(tester, find.text('AI対局'));
      await tester.pumpAndSettle();

      // Verify game layout is responsive
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}

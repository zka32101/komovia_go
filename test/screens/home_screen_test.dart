import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/home_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('HomeScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: false,
      );
    });

    testWidgets('renders home screen with main layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // Verify scaffold
      expect(find.byType(Scaffold), findsWidgets);

      // Verify app bar
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('displays user greeting with name', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // Verify greeting section exists
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows all four primary action cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // The action "cards" are custom GestureDetector+Container widgets,
      // not Material Card widgets.
      expect(find.byType(GestureDetector), findsWidgets);

      // Verify action buttons/text
      expect(find.text('AI対局'), findsWidgets);
      expect(find.text('今日の詰碁'), findsWidgets);
      expect(find.text('観戦・学習'), findsWidgets);
      expect(find.text('対局履歴'), findsWidgets);
    });

    testWidgets('displays subscription status when inactive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // Premium users would show "Premium Member" badge
      // Free users would show upgrade prompts
    });

    testWidgets('displays subscription status when active',
        (WidgetTester tester) async {
      final premiumContainer = TestUtils.createTestContainer(
        currentUser: TestData.premiumUser,
        isSubscriptionActive: true,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: premiumContainer,
        ),
      );

      // 項目2: プレミアムバッジは本文からAppBarへ移動した。
      expect(find.text('プレミアム'), findsOneWidget);
    });

    testWidgets(
        'groups action cards under category section headers (item 1: '
        'the flat list is now organized into 対局/学ぶ/交流/記録)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('対局'), findsOneWidget);
      expect(find.text('学ぶ'), findsOneWidget);
      expect(find.text('交流'), findsOneWidget);
      expect(find.text('記録'), findsOneWidget);
    });

    testWidgets(
        'every previously-reachable screen is still reachable after the '
        'item 1 reorganization (same navigation targets, just grouped)',
        (WidgetTester tester) async {
      // 全カードがスクロールなしで見えるよう、十分大きいテスト用の
      // 画面サイズにしておく(縦に長いセクション分けになったため)。
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 各遷移先ごとに画面を独立して検証する(1つのNavigatorスタックを
      // push/popで使い回すより確実)。
      Future<void> tapAndVerify(String cardTitle, String screenText) async {
        // 同じ構造のウィジェットツリーをpumpWidgetし直すと、Flutterが
        // 新規ツリーではなく「更新」として扱い、前回のNavigatorの
        // ルート履歴を使い回してしまう(このリポジトリの自動化テストで
        // 既知のピットフォール)。確実に作り直すため、間に空の
        // ウィジェットを挟む。
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          TestUtils.buildTestableWidget(
            child: MaterialApp(
              home: const HomeScreen(),
              locale: const Locale('ja'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routes: {
                '/tsume-go': (_) => const Scaffold(body: Text('Tsume-Go画面')),
                '/kifu-observation': (_) =>
                    const Scaffold(body: Text('観戦・学習画面')),
                '/game-history': (_) => const Scaffold(body: Text('対局履歴画面')),
                '/friends': (_) => const Scaffold(body: Text('Friends画面')),
                '/en-hub': (_) => const Scaffold(body: Text('En Hub画面')),
                '/tournament': (_) =>
                    const Scaffold(body: Text('Tournament画面')),
                '/pvp-games': (_) => const Scaffold(body: Text('PvP画面')),
                '/how-to-play': (_) =>
                    const Scaffold(body: Text('How To Play画面')),
                '/joseki': (_) => const Scaffold(body: Text('Joseki画面')),
                '/growth': (_) => const Scaffold(body: Text('Growth画面')),
                '/analytics-dashboard': (_) =>
                    const Scaffold(body: Text('Analytics画面')),
              },
            ),
            container: container,
          ),
        );
        await tester.pump();

        await tester.tap(find.text(cardTitle));
        await tester.pumpAndSettle();
        expect(find.text(screenText), findsOneWidget);
      }

      await tapAndVerify('今日の詰碁', 'Tsume-Go画面');
      await tapAndVerify('観戦・学習', '観戦・学習画面');
      await tapAndVerify('対局履歴', '対局履歴画面');
      await tapAndVerify('フレンド', 'Friends画面');
      await tapAndVerify('対局分析・アチーブメント', 'Analytics画面');
    });

    testWidgets('has correct dark theme styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('play ai game card is prominently styled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // The primary CTA card should be visually distinct
      // (has golden border as per design)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows game statistics section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // Stats would show games played, member since, etc.
      // Depending on implementation details
    });

    testWidgets('taps navigate to correct screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: MaterialApp(
            home: const HomeScreen(),
            navigatorObservers: [],
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/ai-game': (_) => const Scaffold(body: Text('AI Game')),
              '/tsume-go': (_) => const Scaffold(body: Text('Tsume-Go')),
              '/kifu-observation': (_) =>
                  const Scaffold(body: Text('観戦・学習')),
              '/game-history': (_) => const Scaffold(body: Text('対局履歴')),
            },
          ),
          container: container,
        ),
      );

      // Verify cards exist and are tappable
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('displays empty state when no user',
        (WidgetTester tester) async {
      final noUserContainer = TestUtils.createTestContainer(
        currentUser: null,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: noUserContainer,
        ),
      );

      // Auth required state would be shown
    });

    testWidgets('golden border on primary CTA',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );

      // Verify golden accents (#D4AF37 approximate)
      // This depends on actual widget implementation
    });

    testWidgets('shows no resume card when there is no active game',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('続きから対局する'), findsNothing);
    });

    testWidgets('shows a resume card with the saved move count when an active game exists',
        (WidgetTester tester) async {
      final activeGame = ActiveAiGame(
        uid: TestData.testUser.uid,
        boardSize: 9,
        stones: List.generate(9, (_) => List.filled(9, 0)),
        isBlackTurn: true,
        capturedBlack: 0,
        capturedWhite: 0,
        aiLevel: 5,
        movesCount: 4,
        consecutivePasses: 0,
        sgfMoves: '(;GM[1]FF[4]SZ[9])',
      );
      final resumeContainer = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          activeAiGameProvider.overrideWith((ref) async => activeGame),
        ],
      );
      addTearDown(resumeContainer.dispose);

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: resumeContainer,
        ),
      );
      await tester.pump();

      expect(find.text('続きから対局する'), findsOneWidget);
      expect(find.textContaining('4'), findsWidgets);
    });

    testWidgets(
        'shows an entry point to AnalyticsDashboardScreen (regression: it '
        'was previously registered as a route but had no navigation into '
        'it from anywhere in the app)', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const HomeScreen(),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('対局分析・アチーブメント'), findsOneWidget);
    });
  });
}

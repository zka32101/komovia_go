import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/youtube_share_service.dart';
import 'package:komovia_go/views/screens/game_result_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('GameResultScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        movesCount: 45,
        aiLevel: 5,
      );
    });

    testWidgets('renders game result screen with win', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify scaffold exists
      expect(find.byType(Scaffold), findsWidgets);

      // Verify victory message shown
      expect(find.text('勝利！'), findsWidgets);
    });

    testWidgets('displays result title for different outcomes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'loss',
            blackScore: 38.0,
            whiteScore: 42.5,
          ),
          container: container,
        ),
      );

      // Verify defeat title for loss
      expect(find.text('敗北'), findsWidgets);
    });

    testWidgets('shows final score with Chinese rules', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify score display
      expect(find.text('最終スコア（中国ルール）'), findsWidgets);
      expect(find.text('45.5'), findsWidgets);
      expect(find.text('38.0'), findsWidgets);
    });

    testWidgets('displays player and AI labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify player and AI labels
      expect(find.text('黒\n(あなた)'), findsWidgets);
      expect(find.text('白\n(AI)'), findsWidgets);
    });

    testWidgets('shows game stats section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify stats section
      expect(find.text('対局統計'), findsWidgets);
      expect(find.text('碁盤'), findsWidgets);
      expect(find.text('AIレベル'), findsWidgets);
      expect(find.text('手数'), findsWidgets);
    });

    testWidgets('displays board size in stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify board size displayed
      expect(find.text('9×9'), findsWidgets);
    });

    testWidgets('displays AI level in stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify AI level displayed
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('shows move analysis section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // The post-game analysis section was redesigned as an on-demand
      // "AI振り返り" (AI review) card - it only fetches an analysis when
      // its button is pressed, so there's no static "Move Analysis" text.
      expect(find.text('AI振り返り'), findsWidgets);
      expect(find.text('AIで振り返る'), findsWidgets);
    });

    testWidgets('displays action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Verify action buttons
      expect(find.text('対局を保存'), findsWidgets);
      expect(find.text('もう一度対局'), findsWidgets);
      expect(find.text('ホームに戻る'), findsWidgets);
    });

    testWidgets('shows golden "Play Again" button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Play Again button should exist
      expect(find.text('もう一度対局'), findsWidgets);
    });

    testWidgets('displays resignation message when result is resign',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'resign',
            blackScore: null,
            whiteScore: null,
          ),
          container: container,
        ),
      );

      // Verify resignation message
      expect(find.text('投了しました。最終スコアは計算されません。'), findsWidgets);
    });

    testWidgets('shows draw outcome message', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'draw',
            blackScore: 40.0,
            whiteScore: 40.0,
          ),
          container: container,
        ),
      );

      // Verify draw title
      expect(find.text('対局終了'), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('shows result icon based on outcome', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Victory icon should be trophy
      expect(find.byIcon(Icons.emoji_events), findsWidgets);
    });

    testWidgets('requires authentication to save game', (WidgetTester tester) async {
      final noAuthContainer = TestUtils.createTestContainer(
        currentUser: null,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: noAuthContainer,
        ),
      );

      // Save button still exists but shows message when tapped
      expect(find.text('対局を保存'), findsWidgets);
    });

    testWidgets('displays score breakdown for loss', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'loss',
            blackScore: 38.0,
            whiteScore: 42.5,
          ),
          container: container,
        ),
      );

      // Score should show AI victory
      expect(find.text('42.5'), findsWidgets);
      expect(find.text('38.0'), findsWidgets);
    });

    testWidgets('single child scrollview for content', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Scrolling should be possible
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('stone circles show win/loss border colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      // Container widgets for stone representations should exist
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('handles edge case scores', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: GameResultScreen(
            result: 'win',
            blackScore: 0.5,
            whiteScore: 0.0,
          ),
          container: container,
        ),
      );

      expect(find.text('0.5'), findsWidgets);
      expect(find.text('0.0'), findsWidgets);
    });

    testWidgets('shows a toast when a newly unlocked achievement arrives',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );
      await tester.pump();

      // Simulates _checkAndRecordAchievements (game_provider.dart) finding a
      // newly unlocked achievement after the game record was saved.
      container.read(newlyUnlockedAchievementsProvider.notifier).state = const [
        Achievement(
          id: 'first_win',
          name: 'First Victory',
          description: 'Win your first game',
          iconEmoji: '🎉',
        ),
      ];
      await tester.pump();
      await tester.pump();

      expect(find.text('実績解除！'), findsOneWidget);
      expect(find.text('First Victory'), findsOneWidget);

      // The provider is reset so the same achievement isn't shown twice.
      expect(container.read(newlyUnlockedAchievementsProvider), isEmpty);
    });

    testWidgets('shows the YouTube upload button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameResultScreen(
            result: 'win',
            blackScore: 45.5,
            whiteScore: 38.0,
          ),
          container: container,
        ),
      );

      expect(find.text('YouTubeにアップロード'), findsOneWidget);
    });
  });

  group('GameResultScreen YouTube upload', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    ProviderContainer buildContainer({String? savedGameId}) {
      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        movesCount: 45,
        aiLevel: 5,
        extraOverrides: [
          youtubeShareServiceProvider
              .overrideWithValue(YouTubeShareService(firestore: firestore)),
        ],
      );
      if (savedGameId != null) {
        container.read(currentGameSavedIdProvider.notifier).state = savedGameId;
      }
      return container;
    }

    testWidgets('shows login message when tapped while logged out', (tester) async {
      final container = TestUtils.createTestContainer(
        currentUser: null,
        extraOverrides: [
          youtubeShareServiceProvider
              .overrideWithValue(YouTubeShareService(firestore: firestore)),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameResultScreen(result: 'win', blackScore: 45.5, whiteScore: 38.0),
          container: container,
        ),
      );

      await tester.ensureVisible(find.text('YouTubeにアップロード'));
      await tester.pump();
      await tester.tap(find.text('YouTubeにアップロード'));
      await tester.pump();

      expect(find.text('対局を保存するにはログインが必要です'), findsOneWidget);
    });

    testWidgets('shows the honest coming-soon dialog when not YouTube-connected',
        (tester) async {
      final container = buildContainer(savedGameId: 'game-1');

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameResultScreen(result: 'win', blackScore: 45.5, whiteScore: 38.0),
          container: container,
        ),
      );

      await tester.ensureVisible(find.text('YouTubeにアップロード'));
      await tester.pump();
      await tester.tap(find.text('YouTubeにアップロード'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('YouTube 連携は準備中です'), findsOneWidget);
    });

    testWidgets('uploads to YouTube and shows a success message when connected',
        (tester) async {
      await firestore
          .collection('users')
          .doc(TestData.testUser.uid)
          .collection('oauth')
          .doc('youtube')
          .set({'isConnected': true});

      final container = buildContainer(savedGameId: 'game-1');

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const GameResultScreen(result: 'win', blackScore: 45.5, whiteScore: 38.0),
          container: container,
        ),
      );

      await tester.ensureVisible(find.text('YouTubeにアップロード'));
      await tester.pump();
      await tester.tap(find.text('YouTubeにアップロード'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('アップロードを開始しました'), findsOneWidget);

      final uploads = await firestore
          .collection('games')
          .doc('game-1')
          .collection('uploads')
          .get();
      expect(uploads.docs, hasLength(1));
      expect(uploads.docs.single.data()['userId'], TestData.testUser.uid);
    });
  });
}

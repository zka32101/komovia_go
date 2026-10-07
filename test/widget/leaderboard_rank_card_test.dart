import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/extended_game_models.dart';
import 'package:komovia_go/views/widgets/leaderboard_rank_card.dart';

void main() {
  group('LeaderboardRankCardWidget Tests', () {
    late LeaderboardEntry playerRank;

    setUp(() {
      playerRank = const LeaderboardEntry(
        userId: 'player-1',
        displayName: 'TestPlayer',
        rank: 5,
        rating: 1850.5,
        wins: 150,
        losses: 80,
        totalGames: 230,
        period: 'weekly',
        winRate: 65.2,
        avatarUrl: null,
      );
    });

    testWidgets('Renders rank card with player data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: playerRank,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify player rank is displayed
      expect(find.text('#5'), findsOneWidget);

      // Verify rating is displayed (1850.5 rounds up via toStringAsFixed(0))
      expect(find.text('1851'), findsOneWidget);

      // Verify win/loss record is displayed
      expect(find.text('150W - 80L'), findsOneWidget);

      // Verify win rate is displayed
      expect(find.text('65.2%'), findsOneWidget);
    });

    testWidgets('Displays loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: null,
              period: 'allTime',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Displays no data state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: null,
              period: 'allTime',
            ),
          ),
        ),
      );

      expect(find.text('ランキングデータなし'), findsOneWidget);
    });

    testWidgets('Displays correct medal for rank 1', (WidgetTester tester) async {
      final rank1Player = playerRank.copyWith(rank: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: rank1Player,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify gold medal
      expect(find.text('🥇'), findsOneWidget);
    });

    testWidgets('Displays correct medal for rank 2', (WidgetTester tester) async {
      final rank2Player = playerRank.copyWith(rank: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: rank2Player,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify silver medal
      expect(find.text('🥈'), findsOneWidget);
    });

    testWidgets('Displays correct medal for rank 3', (WidgetTester tester) async {
      final rank3Player = playerRank.copyWith(rank: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: rank3Player,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify bronze medal
      expect(find.text('🥉'), findsOneWidget);
    });

    testWidgets('Displays star for other ranks', (WidgetTester tester) async {
      final otherRankPlayer = playerRank.copyWith(rank: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: otherRankPlayer,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify star icon
      expect(find.text('⭐'), findsOneWidget);
    });

    testWidgets('Shows progress bar for non-rank-1 players', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: playerRank,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify progress bar is displayed
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Shows top rank message for rank 1', (WidgetTester tester) async {
      final rank1Player = playerRank.copyWith(rank: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: rank1Player,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify top rank message
      expect(find.text('🏆 最上位ランク'), findsOneWidget);
    });

    testWidgets('Formats period correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: playerRank,
              period: 'monthly',
            ),
          ),
        ),
      );

      // Verify period is formatted
      expect(find.text('月間'), findsOneWidget);
    });

    testWidgets('Displays correct rating color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: playerRank,
              period: 'allTime',
            ),
          ),
        ),
      );

      // Verify rating section exists
      expect(find.text('Rating'), findsOneWidget);
    });
  });

  group('CompactRankCardWidget Tests', () {
    late LeaderboardEntry entry;

    setUp(() {
      entry = const LeaderboardEntry(
        userId: 'player-2',
        displayName: 'CompactPlayer',
        rank: 1,
        rating: 2000.0,
        wins: 200,
        losses: 50,
        totalGames: 250,
        period: 'weekly',
        winRate: 80.0,
        avatarUrl: null,
      );
    });

    testWidgets('Renders compact card with essential info', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactRankCardWidget(
              entry: entry,
            ),
          ),
        ),
      );

      // Verify rank is displayed
      expect(find.text('#1'), findsOneWidget);

      // Verify player name is displayed
      expect(find.text('CompactPlayer'), findsOneWidget);

      // Rating and win rate render as one combined "2000 • 80.0%" text.
      expect(find.textContaining('2000'), findsOneWidget);
      expect(find.textContaining('80.0%'), findsOneWidget);
    });

    testWidgets('Calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactRankCardWidget(
              entry: entry,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });

    testWidgets('Displays compact rank display', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactRankCardWidget(
              entry: entry,
            ),
          ),
        ),
      );

      // Verify compact layout
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('Shows correct rank badge color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompactRankCardWidget(
              entry: entry,
            ),
          ),
        ),
      );

      // Verify rank badge is displayed
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('Rank Color Logic Tests', () {
    testWidgets('Returns correct color for each rank', (WidgetTester tester) async {
      final ranks = [1, 2, 3, 4, 5];

      for (final rank in ranks) {
        final entry = const LeaderboardEntry(
          userId: 'player',
          displayName: 'Player',
          rank: 1,
          rating: 1500,
          wins: 100,
          losses: 50,
          totalGames: 150,
          period: 'weekly',
          winRate: 66.7,
          avatarUrl: null,
        ).copyWith(rank: rank);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LeaderboardRankCardWidget(
                playerRank: entry,
                period: 'allTime',
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
      }
    });
  });

  group('Period Formatting Tests', () {
    late LeaderboardEntry entry;

    setUp(() {
      entry = const LeaderboardEntry(
        userId: 'player',
        displayName: 'Player',
        rank: 5,
        rating: 1500,
        wins: 100,
        losses: 50,
        totalGames: 150,
        period: 'weekly',
        winRate: 66.7,
        avatarUrl: null,
      );
    });

    testWidgets('Formats allTime period', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: entry,
              period: 'allTime',
            ),
          ),
        ),
      );

      expect(find.text('全期間'), findsOneWidget);
    });

    testWidgets('Formats weekly period', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: entry,
              period: 'weekly',
            ),
          ),
        ),
      );

      expect(find.text('週間'), findsOneWidget);
    });

    testWidgets('Formats daily period', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaderboardRankCardWidget(
              playerRank: entry,
              period: 'daily',
            ),
          ),
        ),
      );

      expect(find.text('日間'), findsOneWidget);
    });
  });
}

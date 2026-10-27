import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/growth_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

GameRecord _record({
  required String id,
  required GameResult result,
  required int aiLevel,
  int? ratingAfter,
  int? ratingDelta,
  required DateTime playedAt,
}) {
  return GameRecord(
    id: id,
    uid: TestData.testUser.uid,
    boardSize: 9,
    sgfData: '(;GM[1]SZ[9];B[cc];W[gg])',
    result: result,
    aiLevel: aiLevel,
    playedAt: playedAt,
    movesCount: 2,
    ratingAfter: ratingAfter,
    ratingDelta: ratingDelta,
  );
}

void main() {
  group('GrowthScreen', () {
    testWidgets('shows a login-required message when signed out', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(null),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const GrowthScreen(), container: container),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the current rating and go rank for a signed-in user', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userLeaderboardRankProvider((
            uid: TestData.testUser.uid,
            period: LeaderboardPeriod.allTime,
            type: LeaderboardType.rating,
          )).overrideWith((ref) async => null),
          userGameRecordsProvider(TestData.testUser.uid).overrideWith((ref) async => []),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const GrowthScreen(), container: container),
      );
      await tester.pump();
      await tester.pump();

      // Default rating (1200) shown when no leaderboard entry exists yet.
      expect(find.textContaining('1200'), findsOneWidget);
    });

    testWidgets('shows the empty-history message with zero games', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userLeaderboardRankProvider((
            uid: TestData.testUser.uid,
            period: LeaderboardPeriod.allTime,
            type: LeaderboardType.rating,
          )).overrideWith((ref) async => null),
          userGameRecordsProvider(TestData.testUser.uid).overrideWith((ref) async => []),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const GrowthScreen(), container: container),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('対局記録がありません'), findsOneWidget);
    });

    testWidgets('shows total games and win rate once games exist', (tester) async {
      final records = [
        _record(
          id: 'g1',
          result: GameResult.playerWin,
          aiLevel: 5,
          ratingAfter: 1212,
          ratingDelta: 12,
          playedAt: DateTime(2026, 1, 1),
        ),
        _record(
          id: 'g2',
          result: GameResult.aiWin,
          aiLevel: 5,
          ratingAfter: 1200,
          ratingDelta: -12,
          playedAt: DateTime(2026, 1, 2),
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userLeaderboardRankProvider((
            uid: TestData.testUser.uid,
            period: LeaderboardPeriod.allTime,
            type: LeaderboardType.rating,
          )).overrideWith((ref) async => null),
          // Firestore returns newest-first; keep that order here too.
          userGameRecordsProvider(TestData.testUser.uid)
              .overrideWith((ref) async => records.reversed.toList()),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const GrowthScreen(), container: container),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('2'), findsOneWidget); // total games
      expect(find.text('50%'), findsOneWidget); // win rate
    });

    testWidgets(
      'uses the uncapped leaderboard entry for total games/win rate, not the capped records list',
      (tester) async {
        // userGameRecordsProvider is hard-capped at 20 (game_provider.dart),
        // but a real player can have far more lifetime games. Regression
        // test for the bug where "総対局数"/"勝率" silently showed only the
        // most recent 20 games' stats instead of the lifetime totals the
        // labels claim.
        final records = List.generate(
          20,
          (i) => _record(
            id: 'g$i',
            result: i.isEven ? GameResult.playerWin : GameResult.aiWin,
            aiLevel: 5,
            ratingAfter: 1200 + i,
            ratingDelta: 1,
            playedAt: DateTime(2026, 1, 1 + i),
          ),
        );
        final entry = LeaderboardEntry(
          uid: 'test-uid',
          displayName: 'Test',
          rank: 1,
          rating: 1450,
          gamesPlayed: 150,
          wins: 90,
          winRate: 0.6,
          puzzlesSolved: 0,
          lastUpdated: DateTime(2026, 1, 20),
        );
        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWithValue(TestData.testUser),
            userLeaderboardRankProvider((
              uid: TestData.testUser.uid,
              period: LeaderboardPeriod.allTime,
              type: LeaderboardType.rating,
            )).overrideWith((ref) async => entry),
            userGameRecordsProvider(TestData.testUser.uid)
                .overrideWith((ref) async => records.reversed.toList()),
          ],
        );

        await tester.pumpWidget(
          TestUtils.buildTestableWidget(child: const GrowthScreen(), container: container),
        );
        await tester.pump();
        await tester.pump();

        // Lifetime totals from the LeaderboardEntry, not "20"/"50%" from
        // the capped records list.
        expect(find.text('150'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.text('20'), findsNothing);
        expect(find.text('50%'), findsNothing);
      },
    );
  });
}

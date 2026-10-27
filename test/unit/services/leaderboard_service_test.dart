import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/services/leaderboard_service.dart';

void main() {
  group('periodDocId', () {
    test('allTime is always the fixed doc id regardless of date', () {
      expect(
        periodDocId(LeaderboardPeriod.allTime,
            now: DateTime(2026, 10, 27)),
        'all_time',
      );
      expect(
        periodDocId(LeaderboardPeriod.allTime, now: DateTime(2030, 1, 1)),
        'all_time',
      );
    });

    test('daily encodes the calendar date, zero-padded', () {
      expect(
        periodDocId(LeaderboardPeriod.daily, now: DateTime(2026, 10, 27)),
        'daily_2026-10-27',
      );
      expect(
        periodDocId(LeaderboardPeriod.daily, now: DateTime(2026, 1, 5)),
        'daily_2026-01-05',
      );
    });

    test('monthly encodes year-month, zero-padded', () {
      expect(
        periodDocId(LeaderboardPeriod.monthly, now: DateTime(2026, 10, 27)),
        'monthly_2026-10',
      );
      expect(
        periodDocId(LeaderboardPeriod.monthly, now: DateTime(2026, 1, 1)),
        'monthly_2026-01',
      );
    });

    test('weekly uses ISO 8601 week numbering', () {
      // 2026-10-27 is a Tuesday in ISO week 44 of 2026.
      expect(
        periodDocId(LeaderboardPeriod.weekly, now: DateTime(2026, 10, 27)),
        'weekly_2026-W44',
      );
    });

    test('weekly handles the year-end edge case (week belongs to next year)',
        () {
      // 2024-12-30 is a Monday; ISO week 1 of 2025 starts here because
      // its Thursday (2025-01-02) falls in 2025.
      expect(
        periodDocId(LeaderboardPeriod.weekly, now: DateTime(2024, 12, 30)),
        'weekly_2025-W01',
      );
    });

    test('weekly handles the year-start edge case (week belongs to prior '
        'year)', () {
      // 2023-01-01 is a Sunday; it belongs to ISO week 52 of 2022 because
      // its Thursday (2022-12-29) falls in 2022.
      expect(
        periodDocId(LeaderboardPeriod.weekly, now: DateTime(2023, 1, 1)),
        'weekly_2022-W52',
      );
    });

    test('daily/weekly/monthly produce different doc ids for the same date',
        () {
      final now = DateTime(2026, 10, 27);
      final ids = {
        periodDocId(LeaderboardPeriod.daily, now: now),
        periodDocId(LeaderboardPeriod.weekly, now: now),
        periodDocId(LeaderboardPeriod.monthly, now: now),
        periodDocId(LeaderboardPeriod.allTime, now: now),
      };
      expect(ids, hasLength(4));
    });
  });

  group('LeaderboardService period isolation', () {
    late FakeFirebaseFirestore firestore;
    late LeaderboardService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = LeaderboardService(firestore: firestore);
    });

    test('updateUserScore for one period is invisible to another period',
        () async {
      await service.updateUserScore(
        uid: 'u1',
        displayName: 'Alice',
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.rating,
        rating: 1500,
        gamesPlayed: 10,
        wins: 5,
        puzzlesSolved: 0,
      );

      final dailyEntry = await service.getUserRank(
        uid: 'u1',
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.rating,
      );
      final weeklyEntry = await service.getUserRank(
        uid: 'u1',
        period: LeaderboardPeriod.weekly,
        type: LeaderboardType.rating,
      );
      final allTimeEntry = await service.getUserRank(
        uid: 'u1',
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
      );

      expect(dailyEntry, isNotNull);
      expect(dailyEntry!.rating, 1500);
      expect(weeklyEntry, isNull);
      expect(allTimeEntry, isNull);
    });

    test('getLeaderboard only returns entries written for that exact period',
        () async {
      await service.updateUserScore(
        uid: 'u1',
        displayName: 'Alice',
        period: LeaderboardPeriod.weekly,
        type: LeaderboardType.rating,
        rating: 1600,
        gamesPlayed: 3,
        wins: 2,
        puzzlesSolved: 0,
      );
      await service.updateUserScore(
        uid: 'u2',
        displayName: 'Bob',
        period: LeaderboardPeriod.monthly,
        type: LeaderboardType.rating,
        rating: 1700,
        gamesPlayed: 4,
        wins: 1,
        puzzlesSolved: 0,
      );

      final weekly = await service.getLeaderboard(
        period: LeaderboardPeriod.weekly,
        type: LeaderboardType.rating,
      );
      final monthly = await service.getLeaderboard(
        period: LeaderboardPeriod.monthly,
        type: LeaderboardType.rating,
      );

      expect(weekly.map((e) => e.uid), ['u1']);
      expect(monthly.map((e) => e.uid), ['u2']);
    });

    test('incrementUserStats accumulates within the same period document',
        () async {
      await service.incrementUserStats(
        uid: 'u1',
        displayName: 'Alice',
        type: LeaderboardType.puzzles,
        puzzlesSolvedDelta: 2,
      );
      await service.incrementUserStats(
        uid: 'u1',
        displayName: 'Alice',
        type: LeaderboardType.puzzles,
        puzzlesSolvedDelta: 3,
      );

      final entry = await service.getUserRank(
        uid: 'u1',
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.puzzles,
      );

      expect(entry, isNotNull);
      expect(entry!.puzzlesSolved, 5);
    });

    test(
        'incrementUserStats writes to every period (daily/weekly/monthly/'
        'allTime), not just one, so the daily/weekly/monthly leaderboard '
        'tabs are never permanently empty', () async {
      await service.incrementUserStats(
        uid: 'u1',
        displayName: 'Alice',
        type: LeaderboardType.rating,
        newRating: 1500,
        gamesPlayedDelta: 1,
        winsDelta: 1,
      );

      for (final period in LeaderboardPeriod.values) {
        final entry = await service.getUserRank(
          uid: 'u1',
          period: period,
          type: LeaderboardType.rating,
        );
        expect(entry, isNotNull, reason: 'missing entry for $period');
        expect(entry!.rating, 1500);
      }
    });

    test('resetLeaderboard only clears the specified period', () async {
      await service.updateUserScore(
        uid: 'u1',
        displayName: 'Alice',
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.rating,
        rating: 1500,
        gamesPlayed: 1,
        wins: 1,
        puzzlesSolved: 0,
      );
      await service.updateUserScore(
        uid: 'u1',
        displayName: 'Alice',
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
        rating: 1500,
        gamesPlayed: 1,
        wins: 1,
        puzzlesSolved: 0,
      );

      await service.resetLeaderboard(
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.rating,
      );

      final daily = await service.getLeaderboard(
        period: LeaderboardPeriod.daily,
        type: LeaderboardType.rating,
      );
      final allTime = await service.getLeaderboard(
        period: LeaderboardPeriod.allTime,
        type: LeaderboardType.rating,
      );

      expect(daily, isEmpty);
      expect(allTime, hasLength(1));
    });
  });
}

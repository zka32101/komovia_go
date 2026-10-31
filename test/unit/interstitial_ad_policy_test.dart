import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/interstitial_ad_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = InterstitialAdPolicy();
  final now = DateTime(2026, 10, 31, 12);

  bool decide({
    bool ads = true,
    int moves = 40,
    required int games,
    DateTime? last,
  }) =>
      policy.shouldShow(
        adsEnabled: ads,
        movesPlayed: moves,
        qualifyingGamesCompleted: games,
        lastShownAt: last,
        now: now,
      );

  group('InterstitialAdPolicy', () {
    test('最初の5局は猶予期間で表示しない', () {
      for (var g = 1; g <= 5; g++) {
        expect(decide(games: g), isFalse, reason: 'game $g');
      }
    });

    test('猶予後は3局ごとにのみ表示する', () {
      final shown = [for (var g = 6; g <= 14; g++) if (decide(games: g)) g];
      expect(shown, [8, 11, 14]);
    });

    test('10手未満の対局では表示もカウントもしない', () {
      expect(policy.countsTowardFrequency(9), isFalse);
      expect(policy.countsTowardFrequency(10), isTrue);
      expect(decide(games: 8, moves: 9), isFalse);
    });

    test('前回表示から10分未満なら表示しない', () {
      expect(decide(games: 8, last: now.subtract(const Duration(minutes: 9))), isFalse);
      expect(decide(games: 8, last: now.subtract(const Duration(minutes: 10))), isTrue);
    });

    test('広告除去(プレミアム)ユーザーには一切表示しない', () {
      for (var g = 1; g <= 30; g++) {
        expect(decide(ads: false, games: g), isFalse);
      }
    });
  });

  group('InterstitialAdStateStore', () {
    test('カウンタと最終表示時刻を永続化する', () async {
      SharedPreferences.setMockInitialValues({});
      final store = InterstitialAdStateStore(await SharedPreferences.getInstance());
      expect(store.qualifyingGames, 0);
      expect(store.lastShownAt, isNull);
      expect(await store.incrementQualifyingGames(), 1);
      expect(await store.incrementQualifyingGames(), 2);
      await store.recordShown(now);
      final reloaded = InterstitialAdStateStore(await SharedPreferences.getInstance());
      expect(reloaded.qualifyingGames, 2);
      expect(reloaded.lastShownAt, now);
    });
  });
}

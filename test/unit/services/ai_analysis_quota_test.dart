import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/ai_analysis_quota.dart';
import 'package:komovia_go/services/index.dart' show GameAnalysis;
import 'package:komovia_go/viewmodels/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/test_data.dart';

GameAnalysis _analysis() => GameAnalysis(
      kifuId: 'k',
      moves: const [],
      overallTheme: 't',
      keyTurningPoints: 'p',
      conclusion: 'c',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AiAnalysisQuotaStore', () {
    final day1 = DateTime(2026, 10, 31, 10);

    test('free users get 3 per day, then blocked', () async {
      final store = AiAnalysisQuotaStore(await SharedPreferences.getInstance());
      for (var i = 0; i < 3; i++) {
        expect(store.check(hasPlan: false, now: day1), AiAnalysisAccess.freeQuota);
        await store.recordUse(day1);
      }
      expect(store.remaining(day1), 0);
      expect(store.check(hasPlan: false, now: day1), AiAnalysisAccess.blocked);
    });

    test('resets at midnight (next calendar day)', () async {
      final store = AiAnalysisQuotaStore(await SharedPreferences.getInstance());
      for (var i = 0; i < 3; i++) {
        await store.recordUse(DateTime(2026, 10, 31, 23, 59));
      }
      expect(store.check(hasPlan: false, now: DateTime(2026, 10, 31, 23, 59, 30)),
          AiAnalysisAccess.blocked);
      final nextDay = DateTime(2026, 11, 1, 0, 0, 1);
      expect(store.remaining(nextDay), 3);
      expect(store.check(hasPlan: false, now: nextDay), AiAnalysisAccess.freeQuota);
      await store.recordUse(nextDay);
      expect(store.remaining(nextDay), 2);
    });

    test('plan holders are unlimited even when quota is exhausted', () async {
      final store = AiAnalysisQuotaStore(await SharedPreferences.getInstance());
      for (var i = 0; i < 3; i++) {
        await store.recordUse(day1);
      }
      expect(store.check(hasPlan: true, now: day1), AiAnalysisAccess.unlimited);
    });
  });

  group('gatedGenerateGameAnalysisProvider', () {
    ProviderContainer makeContainer({DateTime? planEnd}) {
      var user = TestData.testUser;
      if (planEnd != null) user = user.copyWith(aiAnalysisPlanEndDate: planEnd);
      return ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(user),
        generateGameAnalysisProvider.overrideWithValue(
          ({required sgfData, required kifuId}) async => _analysis(),
        ),
      ]);
    }

    test('consumes quota and blocks the 4th call for free users', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final gen = c.read(gatedGenerateGameAnalysisProvider);
      for (var i = 0; i < 3; i++) {
        await gen(sgfData: 's', kifuId: 'k');
      }
      expect(() => gen(sgfData: 's', kifuId: 'k'),
          throwsA(isA<AiAnalysisQuotaExceededException>()));
    });

    test('active plan bypasses quota and does not consume it', () async {
      final c = makeContainer(planEnd: DateTime.now().add(const Duration(days: 10)));
      addTearDown(c.dispose);
      final gen = c.read(gatedGenerateGameAnalysisProvider);
      for (var i = 0; i < 5; i++) {
        await gen(sgfData: 's', kifuId: 'k');
      }
      final store = await c.read(aiAnalysisQuotaStoreProvider.future);
      expect(store.remaining(DateTime.now()), 3);
    });

    test('expired plan falls back to free quota', () async {
      final c = makeContainer(planEnd: DateTime.now().subtract(const Duration(days: 1)));
      addTearDown(c.dispose);
      await c.read(gatedGenerateGameAnalysisProvider)(sgfData: 's', kifuId: 'k');
      final store = await c.read(aiAnalysisQuotaStoreProvider.future);
      expect(store.remaining(DateTime.now()), 2);
    });

    test('failed generation does not consume quota', () async {
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(TestData.testUser),
        generateGameAnalysisProvider.overrideWithValue(
          ({required sgfData, required kifuId}) async => throw Exception('net'),
        ),
      ]);
      addTearDown(c.dispose);
      await expectLater(
          c.read(gatedGenerateGameAnalysisProvider)(sgfData: 's', kifuId: 'k'),
          throwsException);
      final store = await c.read(aiAnalysisQuotaStoreProvider.future);
      expect(store.remaining(DateTime.now()), 3);
    });
  });
}

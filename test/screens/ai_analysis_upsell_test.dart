import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/ai_analysis_quota.dart';
import 'package:komovia_go/services/index.dart' show GameAnalysis;
import 'package:komovia_go/views/screens/game_result_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  testWidgets('shows upsell dialog when the daily AI analysis quota is exhausted',
      (tester) async {
    final now = DateTime.now();
    final day =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      AiAnalysisQuotaStore.dateKey: day,
      AiAnalysisQuotaStore.countKey: 3,
    });
    var called = false;
    final container = TestUtils.createTestContainer(
      currentUser: TestData.testUser,
      boardState: TestData.emptyBoardState,
      extraOverrides: [
        generateGameAnalysisProvider.overrideWithValue(
          ({required sgfData, required kifuId}) async {
            called = true;
            return GameAnalysis(
                kifuId: kifuId, moves: const [], overallTheme: '', keyTurningPoints: '', conclusion: '');
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(TestUtils.buildTestableWidget(
      child: GameResultScreen(result: 'win', blackScore: 45.5, whiteScore: 38.0),
      container: container,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('本日の無料AI分析: 残り0回'), findsOneWidget);
    await tester.tap(find.text('AIで振り返る'));
    await tester.pump();
    await tester.pump();

    expect(find.text('本日の上限に達しました'), findsOneWidget);
    expect(find.textContaining('今日のAI分析は上限に達しました'), findsOneWidget);
    expect(find.text('AI分析プランに加入'), findsOneWidget);
    expect(called, isFalse);
  });
}

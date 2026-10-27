import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/achievements_screen.dart';
import 'package:komovia_go/views/screens/analytics_dashboard_screen.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// AnalyticsDashboardScreenのachievementsセクションには「すべて見る」
/// への導線が無く、`AchievementGridWidget.onAchievementTap`も空実装
/// (コメント止まり)だった。全件確認できるAchievementsScreen自体は実装
/// 済みなのに、通知タップ以外に到達する方法が無かった(見出し②の修正)。
void main() {
  group('AnalyticsDashboardScreen', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          analyticsServiceProvider
              .overrideWithValue(AnalyticsService(firestore: firestore)),
        ],
      );
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const AnalyticsDashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows a "view all" button for achievements',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.text('すべて見る'), findsOneWidget);
    });

    testWidgets('tapping "view all" navigates to AchievementsScreen',
        (WidgetTester tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('すべて見る'));
      await tester.pumpAndSettle();

      expect(find.byType(AchievementsScreen), findsOneWidget);
    });

  });
}

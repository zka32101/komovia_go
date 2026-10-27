import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/game_record.dart' as real_game;
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/achievements_screen.dart';

import '../test_utils.dart';

/// 実績を全件確認できる専用画面が無く、トースト以外では
/// AnalyticsDashboardScreen内の「解除済みのみ」の小さなセクションしか
/// 見る場所が無かった（見出し③の修正）。解除済み/未解除(進捗つき)の
/// 両方を一覧できることを確認する。
void main() {
  group('AchievementsScreen', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;
    const uid = 'achv-user';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = TestUtils.createTestContainer(
        extraOverrides: [
          analyticsServiceProvider.overrideWithValue(AnalyticsService(firestore: firestore)),
        ],
      );
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const AchievementsScreen(uid: uid),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('shows the no-achievements message when nothing is unlocked yet',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('アチーブメントを獲得してください'), findsOneWidget);
    });

    testWidgets('shows a locked achievement with progress once the user has played at least one game',
        (tester) async {
      await firestore.collection('gameRecords').doc('g0').set(
        real_game.GameRecord(
          id: 'g0',
          uid: uid,
          boardSize: 9,
          sgfData: '',
          result: real_game.GameResult.aiWin,
          aiLevel: 1,
          playedAt: DateTime.now(),
          gameDuration: const Duration(seconds: 60),
        ).toFirestore(),
      );

      await pumpScreen(tester);

      expect(find.text('未解除'), findsOneWidget);
      expect(find.text('First Victory'), findsOneWidget);
    });

    testWidgets('shows an unlocked achievement after a qualifying game, and excludes it from locked',
        (tester) async {
      await firestore.collection('gameRecords').doc('g1').set(
        real_game.GameRecord(
          id: 'g1',
          uid: uid,
          boardSize: 9,
          sgfData: '',
          result: real_game.GameResult.playerWin,
          aiLevel: 1,
          playedAt: DateTime.now(),
          gameDuration: const Duration(seconds: 60),
        ).toFirestore(),
      );
      // Mirror what checkAndRecordAchievementsAfterGame does: run the
      // check once so the unlock is actually persisted to Firestore,
      // not just computed on the fly.
      await AnalyticsService(firestore: firestore).checkAchievements(userId: uid);

      await pumpScreen(tester);

      expect(find.text('First Victory'), findsOneWidget);
      expect(find.text('アチーブメントを獲得してください'), findsNothing);
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/notification_screen.dart';
import 'package:komovia_go/views/screens/friends_screen.dart';
import 'package:komovia_go/views/screens/achievements_screen.dart';
import 'package:komovia_go/views/screens/tournament_bracket_screen.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// `friend_request`/`tournament_match`/`achievement`通知は、以前は
/// アイコンだけ用意されていてタップしても何も起きず既読になるだけ
/// だった（`pvp_challenge`/`game_invitation`しか遷移先が無かった）。
/// この画面はFriendsScreen(招待待ちタブ)/TournamentBracketScreen/
/// AchievementsScreenへ実際に遷移するようになったことを確認する。
void main() {
  group('NotificationScreen tap targets', () {
    late FakeFirebaseFirestore firestore;
    late NotificationService notificationService;
    late ProviderContainer container;
    const uid = 'test-user-123';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      notificationService = NotificationService(firestore: firestore);
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser, // uid: 'test-user-123'
        extraOverrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
          tournamentServiceProvider.overrideWithValue(TournamentService(firestore)),
        ],
      );
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const NotificationScreen(),
        ),
      );
      await tester.pump();
    }

    testWidgets('tapping a friend_request notification opens the pending-requests tab',
        (tester) async {
      await notificationService.sendNotification(
        uid: uid,
        title: 'フレンド申請',
        body: 'Carolさんからフレンド申請が届きました',
        type: 'friend_request',
      );

      await pumpScreen(tester);
      await tester.tap(find.text('フレンド申請'));
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<FriendsScreen>(find.byType(FriendsScreen));
      expect(screen.initialTabIndex, equals(1));
    });

    testWidgets('tapping a tournament_match notification opens the tournament bracket',
        (tester) async {
      await firestore.collection('tournaments').doc('t1').set({
        'name': 'Test Cup',
        'description': '',
        'startDate': DateTime.now(),
        'endDate': DateTime.now().add(const Duration(days: 1)),
        'maxParticipants': 8,
        'format': 'single_elimination',
        'status': 'active',
        'participantUids': [uid, 'friend-1'],
        'boardSize': 19,
        'createdAt': DateTime.now(),
      });
      await notificationService.sendNotification(
        uid: uid,
        title: '次の対戦相手が決まりました',
        body: 'Carolさんと対局します',
        type: 'tournament_match',
        data: {'tournamentId': 't1', 'matchId': 'm1'},
      );

      await pumpScreen(tester);
      await tester.tap(find.text('次の対戦相手が決まりました'));
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<TournamentBracketScreen>(find.byType(TournamentBracketScreen));
      expect(screen.tournament.id, equals('t1'));
    });

    testWidgets('tapping an achievement notification opens AchievementsScreen',
        (tester) async {
      await notificationService.sendNotification(
        uid: uid,
        title: '実績解除: First Victory',
        body: 'Win your first game',
        type: 'achievement',
        data: {'achievementId': 'first_win'},
      );

      await pumpScreen(tester);
      await tester.tap(find.text('実績解除: First Victory'));
      await tester.pump();
      await tester.pump();

      final screen = tester.widget<AchievementsScreen>(find.byType(AchievementsScreen));
      expect(screen.uid, equals(uid));
    });

    testWidgets('tapping any of these notification types marks it read', (tester) async {
      await notificationService.sendNotification(
        uid: uid,
        title: 'フレンド申請',
        body: 'Carolさんからフレンド申請が届きました',
        type: 'friend_request',
      );

      await pumpScreen(tester);
      await tester.tap(find.text('フレンド申請'));
      await tester.pump();
      await tester.pump();

      final notifications = await notificationService.getUserNotifications(uid);
      expect(notifications.single.isRead, isTrue);
    });
  });
}

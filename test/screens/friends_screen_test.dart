import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/friend_service.dart';
import 'package:komovia_go/services/game_invitation_service.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/friend_provider.dart' as friend_provider;
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/friends_screen.dart';
import 'package:komovia_go/views/screens/pvp_game_screen.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('FriendsScreen search', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(TestData.testUser.uid)
          .set({'displayName': TestData.testUser.displayName});
      await firestore.collection('users').doc('newperson').set({'displayName': 'Newperson'});
      await firestore
          .collection('users')
          .doc('acceptedfriend')
          .set({'displayName': 'Acceptedfriend'});
    });

    ProviderContainer buildContainer() {
      return TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          friendServiceProvider.overrideWithValue(FriendService(firestore: firestore)),
        ],
      );
    }

    Future<void> openSearchAndQuery(
      WidgetTester tester,
      ProviderContainer container,
      String query,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const FriendsScreen(), container: container),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), query);
      await tester.tap(find.text('検索'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows an "追加" button for a user with no existing relationship', (tester) async {
      final container = buildContainer();
      await openSearchAndQuery(tester, container, 'Newperson');

      expect(find.text('追加'), findsOneWidget);
    });

    testWidgets('shows "フレンド" instead of "追加" for an already-accepted friend', (tester) async {
      // Reproduces the bug this session fixed: search used to always show
      // "追加" regardless of existing relationship status, so tapping it
      // on an already-accepted friend would silently reset the friendship
      // back to 'pending' (FriendService.addFriend now refuses that, and
      // the UI should never offer the button in the first place here).
      final service = FriendService(firestore: firestore);
      await service.addFriend(currentUid: TestData.testUser.uid, friendUid: 'acceptedfriend');
      await service.acceptFriendRequest(
        currentUid: TestData.testUser.uid,
        friendUid: 'acceptedfriend',
      );

      final container = buildContainer();
      await openSearchAndQuery(tester, container, 'Acceptedfriend');

      // 'フレンド' also appears as the first tab's label, so scope the
      // assertion to the search result row itself.
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text('フレンド')),
        findsOneWidget,
      );
      expect(find.text('追加'), findsNothing);
    });
  });

  group('FriendsScreen pending requests', () {
    late FakeFirebaseFirestore firestore;
    late FriendService friendService;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      friendService = FriendService(firestore: firestore);
      await firestore
          .collection('users')
          .doc(TestData.testUser.uid)
          .set({'displayName': TestData.testUser.displayName});
      await firestore.collection('users').doc('other-uid').set({'displayName': 'Carol'});
    });

    ProviderContainer buildContainer() {
      return TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          friendServiceProvider.overrideWithValue(friendService),
        ],
      );
    }

    testWidgets('an incoming request shows accept and decline', (tester) async {
      await friendService.addFriend(currentUid: 'other-uid', friendUid: TestData.testUser.uid);

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 1),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('リクエスト待機中'), findsOneWidget);
      expect(find.text('承認'), findsOneWidget);
      expect(find.text('拒否'), findsOneWidget);
      expect(find.text('キャンセル'), findsNothing);
    });

    testWidgets('a request the current user sent shows cancel only', (tester) async {
      await friendService.addFriend(currentUid: TestData.testUser.uid, friendUid: 'other-uid');

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 1),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('送信済み'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);
      expect(find.text('承認'), findsNothing);
      expect(find.text('拒否'), findsNothing);
    });

    testWidgets('declining an incoming request removes it from both sides', (tester) async {
      await friendService.addFriend(currentUid: 'other-uid', friendUid: TestData.testUser.uid);

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 1),
          container: container,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('拒否'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Carol'), findsNothing);
      expect(
        await friendService.getFriendStatus(currentUid: 'other-uid', friendUid: TestData.testUser.uid),
        isNull,
      );
    });

    testWidgets('canceling a sent request removes it from both sides', (tester) async {
      await friendService.addFriend(currentUid: TestData.testUser.uid, friendUid: 'other-uid');

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 1),
          container: container,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('キャンセル'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Carol'), findsNothing);
      expect(
        await friendService.getFriendStatus(currentUid: 'other-uid', friendUid: TestData.testUser.uid),
        isNull,
      );
    });
  });

  group('FriendsScreen game invitations', () {
    late FakeFirebaseFirestore firestore;
    late GameInvitationService invitationService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      invitationService = GameInvitationService(firestore: firestore);
    });

    ProviderContainer buildContainer() {
      return TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          gameInvitationServiceProvider.overrideWithValue(invitationService),
          pvpGameServiceProvider.overrideWithValue(PvpGameService(firestore)),
          spectatorServiceProvider.overrideWithValue(SpectatorService(firestore)),
          friend_provider.friendServiceProvider
              .overrideWithValue(FriendService(firestore: firestore)),
        ],
      );
    }

    testWidgets('shows the empty state when there are no invitations', (tester) async {
      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 2),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('対局の招待はありません'), findsOneWidget);
    });

    testWidgets('shows an incoming invitation with the sender\'s name and board size',
        (tester) async {
      await invitationService.sendInvitation(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: TestData.testUser.uid,
        toDisplayName: TestData.testUser.displayName!,
        boardSize: 13,
      );

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 2),
          container: container,
        ),
      );
      await tester.pump();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.textContaining('13'), findsOneWidget);
      expect(find.text('承認'), findsOneWidget);
      expect(find.text('拒否'), findsOneWidget);
    });

    testWidgets('accepting an invitation creates a PvP game and opens it', (tester) async {
      await invitationService.sendInvitation(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: TestData.testUser.uid,
        toDisplayName: TestData.testUser.displayName!,
        boardSize: 9,
      );

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 2),
          container: container,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('承認'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PvpGameScreen), findsOneWidget);

      final games = await firestore.collection('pvp_games').get();
      expect(games.docs, hasLength(1));
      final game = games.docs.single.data();
      expect(game['boardSize'], 9);
      // Inviter plays black, matching the "founder plays black" convention.
      expect(game['blackUid'], 'friend-1');
      expect(game['whiteUid'], TestData.testUser.uid);
    });

    testWidgets('declining an invitation removes it from the list', (tester) async {
      await invitationService.sendInvitation(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: TestData.testUser.uid,
        toDisplayName: TestData.testUser.displayName!,
        boardSize: 19,
      );

      final container = buildContainer();
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const FriendsScreen(initialTabIndex: 2),
          container: container,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('拒否'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Carol'), findsNothing);
      expect(find.text('対局の招待はありません'), findsOneWidget);
    });

    testWidgets('sending an invitation from the friends list uses the selected board size',
        (tester) async {
      final friendService = FriendService(firestore: firestore);
      await firestore
          .collection('users')
          .doc(TestData.testUser.uid)
          .set({'displayName': TestData.testUser.displayName});
      await firestore.collection('users').doc('friend-1').set({'displayName': 'Dave'});
      await friendService.addFriend(currentUid: TestData.testUser.uid, friendUid: 'friend-1');
      await friendService.acceptFriendRequest(currentUid: TestData.testUser.uid, friendUid: 'friend-1');

      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          gameInvitationServiceProvider.overrideWithValue(invitationService),
          friendServiceProvider.overrideWithValue(friendService),
          friend_provider.friendServiceProvider.overrideWithValue(friendService),
        ],
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(child: const FriendsScreen(), container: container),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Drives the real onSelected callback directly rather than tapping
      // through the popup menu's open/select animation - PopupMenuButton's
      // own internal route-pop-then-callback sequence didn't reliably
      // settle under pump() in this screen, but this still exercises the
      // exact callback FriendListWidget wires to the 'invite' menu item.
      final popupButton = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      popupButton.onSelected!('invite');
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('9 × 9'));
      await tester.pump();
      await tester.tap(find.text('招待を送る'));
      await tester.pump();
      await tester.pump();

      final outgoing = await invitationService.getOutgoingInvitations(uid: TestData.testUser.uid);
      expect(outgoing, hasLength(1));
      expect(outgoing.single.boardSize, 9);
      expect(outgoing.single.toUid, 'friend-1');
    });
  });
}

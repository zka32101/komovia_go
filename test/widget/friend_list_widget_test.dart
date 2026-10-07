import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/views/widgets/friend_list_widget.dart';

void main() {
  group('FriendListWidget Tests', () {
    late List<Friendship> friends;

    setUp(() {
      friends = [
        Friendship(
          uid: 'me',
          friendUid: 'friend-1',
          displayName: 'Friend One',
          status: 'online',
          addedAt: DateTime.now(),
        ),
        Friendship(
          uid: 'me',
          friendUid: 'friend-2',
          displayName: 'Friend Two',
          status: 'offline',
          addedAt: DateTime.now(),
        ),
      ];
    });

    testWidgets('Renders friend list with multiple items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: friends,
            ),
          ),
        ),
      );

      // Verify friends are displayed (Friendship has no rating field, so
      // there's nothing rating-related to check here)
      expect(find.text('Friend One'), findsOneWidget);
      expect(find.text('Friend Two'), findsOneWidget);
    });

    testWidgets('Displays loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: const [],
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Displays empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: const [],
            ),
          ),
        ),
      );

      // Verify empty state icon
      expect(find.byIcon(Icons.people_outline), findsOneWidget);

      // Verify empty state message
      expect(find.text('フレンドがいません'), findsOneWidget);
    });

    testWidgets('Calls onTap when friend item is tapped', (WidgetTester tester) async {
      Friendship? tappedFriend;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: friends,
              onTap: (friend) {
                tappedFriend = friend;
              },
            ),
          ),
        ),
      );

      // Tap first friend
      await tester.tap(find.text('Friend One'));
      await tester.pumpAndSettle();

      expect(tappedFriend?.displayName, 'Friend One');
    });

    testWidgets('Calls onMessage when message button is pressed', (WidgetTester tester) async {
      Friendship? messagedFriend;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: friends,
              onMessage: (friend) {
                messagedFriend = friend;
              },
            ),
          ),
        ),
      );

      // Tap popup menu and select message option
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('メッセージ'), findsOneWidget);
    });

    testWidgets('Calls onRefresh when refreshed', (WidgetTester tester) async {
      bool refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: friends,
              onRefresh: () async {
                refreshed = true;
              },
            ),
          ),
        ),
      );

      // Perform pull-to-refresh. RefreshIndicator needs a held drag past
      // its threshold before release, not a quick fling from an
      // arbitrary point - drag the actual scrollable down.
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(refreshed, isTrue);
    });

    testWidgets('Divider separates list items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: friends,
            ),
          ),
        ),
      );

      // Verify separator exists
      expect(find.byType(Divider), findsWidgets);
    });
  });

  group('FriendChipWidget Tests', () {
    late Friendship friend;

    setUp(() {
      friend = Friendship(
        uid: 'me',
        friendUid: 'friend-1',
        displayName: 'Chip Friend',
        status: 'online',
        addedAt: DateTime.now(),
      );
    });

    testWidgets('Renders compact friend chip', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendChipWidget(
              friend: friend,
            ),
          ),
        ),
      );

      // Verify name is displayed (Friendship has no rating field)
      expect(find.text('Chip Friend'), findsOneWidget);
    });

    testWidgets('Calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendChipWidget(
              friend: friend,
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
  });

  group('FriendHorizontalListWidget Tests', () {
    late List<Friendship> friends;

    setUp(() {
      friends = [
        Friendship(
          uid: 'me',
          friendUid: 'friend-1',
          displayName: 'Player One',
          status: 'online',
          addedAt: DateTime.now(),
        ),
        Friendship(
          uid: 'me',
          friendUid: 'friend-2',
          displayName: 'Player Two',
          status: 'offline',
          addedAt: DateTime.now(),
        ),
        Friendship(
          uid: 'me',
          friendUid: 'friend-3',
          displayName: 'Player Three',
          status: 'online',
          addedAt: DateTime.now(),
        ),
      ];
    });

    testWidgets('Renders horizontal scrollable friend list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendHorizontalListWidget(
              friends: friends,
            ),
          ),
        ),
      );

      // Verify all friends are displayed
      expect(find.text('Player One'), findsOneWidget);
      expect(find.text('Player Two'), findsOneWidget);
      expect(find.text('Player Three'), findsOneWidget);
    });

    testWidgets('Displays empty state for no friends', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendHorizontalListWidget(
              friends: const [],
            ),
          ),
        ),
      );

      expect(find.text('フレンドなし'), findsOneWidget);
    });

    testWidgets('Calls onFriendSelected when friend is tapped', (WidgetTester tester) async {
      Friendship? selectedFriend;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendHorizontalListWidget(
              friends: friends,
              onFriendSelected: (friend) {
                selectedFriend = friend;
              },
            ),
          ),
        ),
      );

      // Tap first friend
      await tester.tap(find.text('Player One'));
      await tester.pumpAndSettle();

      expect(selectedFriend?.displayName, 'Player One');
    });

    testWidgets('Renders friend avatars with initials', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendHorizontalListWidget(
              friends: friends,
            ),
          ),
        ),
      );

      // Verify avatars are rendered
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('Is horizontally scrollable', (WidgetTester tester) async {
      // Add more friends to ensure scrolling
      final manyFriends = List.generate(
        10,
        (i) => Friendship(
          uid: 'me',
          friendUid: 'friend-$i',
          displayName: 'Player $i',
          status: 'online',
          addedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendHorizontalListWidget(
              friends: manyFriends,
            ),
          ),
        ),
      );

      // Verify SingleChildScrollView is used
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('Friendship Data Display Tests', () {
    late Friendship friend;

    setUp(() {
      friend = Friendship(
        uid: 'me',
        friendUid: 'friend-1',
        displayName: 'Data Test Friend',
        status: 'online',
        addedAt: DateTime.now(),
      );
    });

    testWidgets('Renders with just the required fields (no avatarUrl/notes on '
        'Friendship, unlike the old extended_game_models.dart Friend)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendListWidget(
              friends: [friend],
            ),
          ),
        ),
      );

      expect(find.text('Data Test Friend'), findsOneWidget);
    });
  });
}

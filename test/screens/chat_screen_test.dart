import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/direct_message_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/chat_screen.dart';

import '../test_utils.dart';

void main() {
  group('ChatScreen', () {
    late FakeFirebaseFirestore firestore;
    late DirectMessageService service;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = DirectMessageService(firestore);
      container = TestUtils.createTestContainer(
        extraOverrides: [
          directMessageServiceProvider.overrideWithValue(service),
        ],
      );
    });

    Widget buildScreen() {
      return TestUtils.buildTestableWidget(
        container: container,
        child: const ChatScreen(
          currentUid: 'uid1',
          currentDisplayName: 'Alice',
          friendUid: 'uid2',
          friendDisplayName: 'Bob',
        ),
      );
    }

    testWidgets('shows the empty state when no messages exist yet', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('まだメッセージがありません。最初のメッセージを送ってみましょう。'), findsOneWidget);
    });

    testWidgets('shows the friend\'s display name in the app bar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('opening the screen marks the thread read for the current user',
        (tester) async {
      // Seed an existing thread with unread messages for uid1.
      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      await firestore.collection('message_threads').doc(threadId).set({
        'participantUids': ['uid1', 'uid2'],
        'participantNames': {'uid1': 'Alice', 'uid2': 'Bob'},
        'lastMessage': 'hey',
        'unreadCount': {'uid1': 3, 'uid2': 0},
      });

      await tester.pumpWidget(buildScreen());
      await tester.pump();

      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      final unread = Map<String, dynamic>.from(threadDoc.data()!['unreadCount'] as Map);
      expect(unread['uid1'], equals(0));
    });

    testWidgets('renders existing messages aligned by sender', (tester) async {
      await service.sendMessage(
        fromUid: 'uid1',
        fromDisplayName: 'Alice',
        toUid: 'uid2',
        toDisplayName: 'Bob',
        content: 'Hi Bob',
      );
      await service.sendMessage(
        fromUid: 'uid2',
        fromDisplayName: 'Bob',
        toUid: 'uid1',
        toDisplayName: 'Alice',
        content: 'Hi Alice',
      );

      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump();

      expect(find.text('Hi Bob'), findsOneWidget);
      expect(find.text('Hi Alice'), findsOneWidget);
    });

    testWidgets('typing and tapping send delivers the message', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'New message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();

      expect(find.text('New message'), findsOneWidget);

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.data()!['lastMessage'], equals('New message'));
    });

    testWidgets('sending a blank message does nothing', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      final threadId = DirectMessageService.threadIdFor('uid1', 'uid2');
      final threadDoc = await firestore.collection('message_threads').doc(threadId).get();
      expect(threadDoc.exists, isFalse);
    });
  });
}

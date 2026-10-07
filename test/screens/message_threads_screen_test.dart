import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/direct_message_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/chat_screen.dart';
import 'package:komovia_go/views/screens/message_threads_screen.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('MessageThreadsScreen', () {
    late FakeFirebaseFirestore firestore;
    late DirectMessageService service;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = DirectMessageService(firestore);
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser, // uid: 'test-user-123'
        extraOverrides: [
          directMessageServiceProvider.overrideWithValue(service),
        ],
      );
    });

    testWidgets('shows the empty state when there are no conversations', (tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const MessageThreadsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('まだ会話がありません'), findsOneWidget);
    });

    testWidgets('lists existing threads with the other participant\'s name, '
        'last message and unread badge', (tester) async {
      await service.sendMessage(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: 'test-user-123',
        toDisplayName: 'Test Player',
        content: 'See you tomorrow',
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const MessageThreadsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('See you tomorrow'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('tapping a thread opens ChatScreen for the other participant',
        (tester) async {
      await service.sendMessage(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: 'test-user-123',
        toDisplayName: 'Test Player',
        content: 'Hey there',
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const MessageThreadsScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Carol'));
      await tester.pumpAndSettle();

      final chatScreen = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chatScreen.friendUid, equals('friend-1'));
      expect(chatScreen.friendDisplayName, equals('Carol'));
      expect(chatScreen.currentUid, equals('test-user-123'));
    });

    testWidgets('does not show an unread badge once the thread has been read',
        (tester) async {
      await service.sendMessage(
        fromUid: 'friend-1',
        fromDisplayName: 'Carol',
        toUid: 'test-user-123',
        toDisplayName: 'Test Player',
        content: 'Hey there',
      );
      final threadId = DirectMessageService.threadIdFor('test-user-123', 'friend-1');
      await service.markThreadRead(threadId: threadId, uid: 'test-user-123');

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          container: container,
          child: const MessageThreadsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsNothing);
    });
  });
}

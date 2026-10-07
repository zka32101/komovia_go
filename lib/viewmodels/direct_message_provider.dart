import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/direct_message.dart';
import '../services/direct_message_service.dart';

final directMessageServiceProvider = Provider<DirectMessageService>((ref) {
  return DirectMessageService(FirebaseFirestore.instance);
});

/// [uid]が参加している全メッセージスレッド（新しい順）。
final messageThreadsProvider =
    StreamProvider.family<List<MessageThread>, String>((ref, uid) {
  final service = ref.watch(directMessageServiceProvider);
  return service.watchThreadsForUser(uid);
});

/// 1つのスレッド内のメッセージ一覧（古い順）。
final threadMessagesProvider =
    StreamProvider.family<List<DirectMessage>, String>((ref, threadId) {
  final service = ref.watch(directMessageServiceProvider);
  return service.watchMessages(threadId);
});

/// [uid]の全スレッドをまたいだ未読メッセージ数の合計。
final unreadMessageCountProvider = Provider.family<int, String>((ref, uid) {
  final threadsAsync = ref.watch(messageThreadsProvider(uid));
  final threads = threadsAsync.valueOrNull;
  if (threads == null) return 0;
  return threads.fold<int>(0, (sum, thread) => sum + thread.unreadCountFor(uid));
});

final sendDirectMessageProvider = Provider((ref) {
  final service = ref.watch(directMessageServiceProvider);
  return ({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) {
    return service.sendMessage(
      fromUid: fromUid,
      fromDisplayName: fromDisplayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      content: content,
    );
  };
});

final markThreadReadProvider = Provider((ref) {
  final service = ref.watch(directMessageServiceProvider);
  return ({required String threadId, required String uid}) {
    return service.markThreadRead(threadId: threadId, uid: uid);
  };
});

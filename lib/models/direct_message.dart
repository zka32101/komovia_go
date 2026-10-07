import 'package:cloud_firestore/cloud_firestore.dart';

/// フレンド間の1対1メッセージスレッド（`message_threads/{threadId}`）。
/// threadIdは常に両者のuidをソートして連結した決定的なID
/// （DirectMessageService.threadIdFor参照）なので、どちらが先に
/// メッセージを送ってもスレッドが重複して作られることはない。
class MessageThread {
  final String id;
  final List<String> participantUids;
  final Map<String, String> participantNames;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderUid;
  final Map<String, int> unreadCount;

  MessageThread({
    required this.id,
    required this.participantUids,
    required this.participantNames,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderUid,
    required this.unreadCount,
  });

  /// [myUid]以外の参加者のuid（グループ化は未対応なので常に1人）。
  String otherUidFor(String myUid) {
    return participantUids.firstWhere((uid) => uid != myUid, orElse: () => '');
  }

  String otherDisplayNameFor(String myUid) {
    return participantNames[otherUidFor(myUid)] ?? 'Unknown';
  }

  int unreadCountFor(String uid) => unreadCount[uid] ?? 0;

  factory MessageThread.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MessageThread(
      id: doc.id,
      participantUids: List<String>.from(data['participantUids'] as List? ?? const []),
      participantNames: Map<String, String>.from(
        (data['participantNames'] as Map?) ?? const {},
      ),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: data['lastMessageAt'] != null
          ? (data['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastSenderUid: data['lastSenderUid'] as String?,
      unreadCount: Map<String, int>.from((data['unreadCount'] as Map?) ?? const {}),
    );
  }
}

/// `message_threads/{threadId}/messages/{messageId}`の1件。
class DirectMessage {
  final String id;
  final String fromUid;
  final String content;
  final DateTime sentAt;

  DirectMessage({
    required this.id,
    required this.fromUid,
    required this.content,
    required this.sentAt,
  });

  factory DirectMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DirectMessage(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      content: data['content'] as String? ?? '',
      sentAt: data['sentAt'] != null
          ? (data['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUid': fromUid,
      'content': content,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }
}

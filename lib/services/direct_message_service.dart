import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// `MessageThread`/`DirectMessage` have no storage dependency (see
/// komovia_core's doc comments) - converting to/from Firestore's
/// `DocumentSnapshot`/`Timestamp` is this service's own responsibility.
MessageThread _threadFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return MessageThread.fromJson({
    ...data,
    'id': doc.id,
    'lastMessageAt': data['lastMessageAt'] is Timestamp
        ? (data['lastMessageAt'] as Timestamp).toDate().toIso8601String()
        : data['lastMessageAt'],
  });
}

DirectMessage _messageFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return DirectMessage.fromJson({
    ...data,
    'id': doc.id,
    'sentAt': data['sentAt'] is Timestamp
        ? (data['sentAt'] as Timestamp).toDate().toIso8601String()
        : data['sentAt'],
  });
}

/// フレンド間の1対1メッセージング。
class DirectMessageService {
  final FirebaseFirestore _firestore;

  DirectMessageService(this._firestore);

  CollectionReference<Map<String, dynamic>> get _threads =>
      _firestore.collection('message_threads');

  /// 2者のuidから決定的なthreadIdを作る（ソートして連結）ことで、どちらが
  /// 先に送信してもスレッドが重複して作られないようにする。
  static String threadIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    // FriendService.blockFriend mirrors a block onto both sides' own
    // `friends` entries, so checking the sender's own (readable) entry
    // catches a block placed by either party.
    final relationship = await _firestore
        .collection('users')
        .doc(fromUid)
        .collection('friends')
        .doc(toUid)
        .get();
    if (relationship.data()?['status'] == 'blocked') {
      _logger.w('sendMessage refused: $fromUid/$toUid have a blocked relationship');
      return;
    }

    final threadId = threadIdFor(fromUid, toUid);
    final threadRef = _threads.doc(threadId);
    final messageRef = threadRef.collection('messages').doc();

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.set(messageRef, {
      'fromUid': fromUid,
      'content': trimmed,
      'sentAt': Timestamp.fromDate(now),
    });

    batch.set(
      threadRef,
      {
        'participantUids': [fromUid, toUid],
        'participantNames': {fromUid: fromDisplayName, toUid: toDisplayName},
        'lastMessage': trimmed,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastSenderUid': fromUid,
        'unreadCount.$toUid': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    _logger.i('Direct message sent: thread=$threadId from=$fromUid');
  }

  Stream<List<MessageThread>> watchThreadsForUser(String uid) {
    return _threads
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _threadFromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  Stream<List<DirectMessage>> watchMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _messageFromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  /// [uid]がこのスレッドを開いた際に未読数をリセットする。ChatScreenは
  /// 一度もメッセージを送っていない相手を開いた場合でも呼ぶため、スレッ
  /// ドがまだ存在しないケースは何もせず戻る（setでmerge書き込みすると、
  /// メッセージが無いのに空のスレッドドキュメントが作られ、受信箱に
  /// 空の会話が表示されてしまう）。
  Future<void> markThreadRead({required String threadId, required String uid}) async {
    final ref = _threads.doc(threadId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    await ref.update({'unreadCount.$uid': 0});
  }
}

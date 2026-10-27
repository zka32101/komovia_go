import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:logger/logger.dart';
import 'firestore_time.dart';
import '../utils/dm_presets.dart';

final _logger = Logger();

/// `MessageThread`/`DirectMessage` have no storage dependency (see
/// komovia_core's doc comments) - converting to/from Firestore's
/// `DocumentSnapshot`/`Timestamp` is this service's own responsibility.
MessageThread _threadFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return MessageThread.fromJson({
    ...data,
    'id': doc.id,
    'lastMessageAt': isoFromTimestamp(data['lastMessageAt']),
  });
}

DirectMessage _messageFromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return DirectMessage.fromJson({
    ...data,
    'id': doc.id,
    'sentAt': isoFromTimestamp(data['sentAt']),
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

    // 相手を煽る・中傷するような自由入力を一切許さない方針のため、DMは
    // dm_presets.dartのカタログ内の固定フレーズ/絵文字のみ送信できる。
    // ChatScreenは既にこのカタログからの選択UIのみを提供しているが、
    // サービス層でも再確認する（UIを経由しない直接呼び出しへの防御）。
    if (!isAllowedDmContent(trimmed)) {
      _logger.w('sendMessage refused: content is not an allowed preset/emoji');
      return;
    }

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

    // firestore.rules' message_threads update rule requires
    // participantUids to stay byte-for-byte unchanged across writes
    // (list equality is order-sensitive) - writing [fromUid, toUid] here
    // flips the array's order depending on who is sending *this*
    // message, so every other reply in a thread (whichever party isn't
    // the thread's original creator) would have its write rejected.
    // Use the same stable sort threadIdFor already derives the doc id
    // from, so the array never changes shape across senders.
    final sortedUids = [fromUid, toUid]..sort();

    batch.set(
      threadRef,
      {
        'participantUids': sortedUids,
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

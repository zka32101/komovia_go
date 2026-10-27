import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';

final _logger = Logger();

/// 「縁」スコア - フレンドシップの長さ、対戦回数、共に観戦した回数、
/// 局面の轍の重なりから、2人の間の「縁」の深さを算出する
class EnScoreService {
  final FirebaseFirestore _firestore;

  EnScoreService(this._firestore);

  Future<int> _countMatchesPlayed(String uid, String friendUid) async {
    try {
      final asP1 = await _firestore
          .collection('match_results')
          .where('player1Uid', isEqualTo: uid)
          .where('player2Uid', isEqualTo: friendUid)
          .get();
      final asP2 = await _firestore
          .collection('match_results')
          .where('player1Uid', isEqualTo: friendUid)
          .where('player2Uid', isEqualTo: uid)
          .get();
      return asP1.docs.length + asP2.docs.length;
    } catch (e) {
      _logger.e('Error counting matches played: $e');
      return 0;
    }
  }

  Future<int> _countSharedSpectateSessions(String uid, String friendUid) async {
    try {
      // spectator_sessionsのhostUidはspectatorUids配列には入らない
      // (SpectatorService.createSpectatorSessionがspectatorUids: []で
      // 作成し、ホスト自身を観戦者として追加することはない)。そのため
      // 「uidが観戦者として入っているセッション」だけをarrayContainsで
      // 検索すると、uid自身がホストだった共同観戦セッションが一件も
      // 返ってこず、_countSharedSpectateSessions(hostUid, friendUid)と
      // _countSharedSpectateSessions(friendUid, hostUid)で結果が非対称
      // になっていた(友人が観戦者側から数えると見つかるのに、ホスト側
      // から数えるとゼロになる)。uidが観戦者として参加したセッションと、
      // uidがホストだったセッションの両方を取得し、重複を除いて走査する。
      final asSpectator = await _firestore
          .collection('spectator_sessions')
          .where('spectatorUids', arrayContains: uid)
          .get();
      final asHost = await _firestore
          .collection('spectator_sessions')
          .where('hostUid', isEqualTo: uid)
          .get();

      final seenIds = <String>{};
      var count = 0;
      for (final doc in [...asSpectator.docs, ...asHost.docs]) {
        if (!seenIds.add(doc.id)) continue;
        final spectators = List<String>.from(doc.data()['spectatorUids'] as List<dynamic>? ?? []);
        final hostUid = doc.data()['hostUid'] as String?;
        if (spectators.contains(friendUid) || hostUid == friendUid) {
          count++;
        }
      }
      return count;
    } catch (e) {
      _logger.e('Error counting shared spectate sessions: $e');
      return 0;
    }
  }

  Future<int> _countSharedPositionEchoes(String uid, String friendUid) async {
    try {
      final myEchoes = await _firestore
          .collection('position_echoes')
          .where('uid', isEqualTo: uid)
          .limit(200)
          .get();
      final friendEchoes = await _firestore
          .collection('position_echoes')
          .where('uid', isEqualTo: friendUid)
          .limit(200)
          .get();

      final myHashes = myEchoes.docs.map((doc) => doc.data()['positionHash'] as String).toSet();
      final friendHashes =
          friendEchoes.docs.map((doc) => doc.data()['positionHash'] as String).toSet();
      return myHashes.intersection(friendHashes).length;
    } catch (e) {
      _logger.e('Error counting shared position echoes: $e');
      return 0;
    }
  }

  /// 「縁」スコアを算出して保存する
  Future<EnConnection> calculateEnScore({
    required String uid,
    required String friendUid,
    required String friendDisplayName,
    required DateTime friendshipStartedAt,
  }) async {
    try {
      final friendshipDays = DateTime.now().difference(friendshipStartedAt).inDays;
      final matchesPlayed = await _countMatchesPlayed(uid, friendUid);
      final sharedSpectateSessions = await _countSharedSpectateSessions(uid, friendUid);
      final sharedPositionEchoes = await _countSharedPositionEchoes(uid, friendUid);

      // 重み付け: 友情の長さ(最大20点) + 対戦(1試合5点、最大30点)
      // + 共同観戦(1回3点、最大25点) + 局面の重なり(1回5点、最大25点)
      final friendshipScore = (friendshipDays / 3).clamp(0, 20);
      final matchesScore = (matchesPlayed * 5).clamp(0, 30);
      final spectateScore = (sharedSpectateSessions * 3).clamp(0, 25);
      final echoScore = (sharedPositionEchoes * 5).clamp(0, 25);
      final totalScore = (friendshipScore + matchesScore + spectateScore + echoScore).round();

      final connection = EnConnection(
        uid: uid,
        friendUid: friendUid,
        friendDisplayName: friendDisplayName,
        score: totalScore.clamp(0, 100),
        friendshipDays: friendshipDays,
        matchesPlayed: matchesPlayed,
        sharedSpectateSessions: sharedSpectateSessions,
        sharedPositionEchoes: sharedPositionEchoes,
        calculatedAt: DateTime.now(),
      );

      await _firestore
          .collection('en_scores')
          .doc(uid)
          .collection('connections')
          .doc(friendUid)
          .set(connection.toFirestore());

      _logger.i('Calculated en score for $uid <-> $friendUid: ${connection.score} (${connection.level})');
      return connection;
    } catch (e) {
      _logger.e('Error calculating en score: $e');
      rethrow;
    }
  }

  Future<List<EnConnection>> getEnConnections(String uid) async {
    try {
      final snapshots = await _firestore
          .collection('en_scores')
          .doc(uid)
          .collection('connections')
          .orderBy('score', descending: true)
          .get();
      return snapshots.docs.map((doc) => EnConnection.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting en connections: $e');
      rethrow;
    }
  }

  Future<EnConnection?> getEnConnection(String uid, String friendUid) async {
    try {
      final doc = await _firestore
          .collection('en_scores')
          .doc(uid)
          .collection('connections')
          .doc(friendUid)
          .get();
      if (!doc.exists) return null;
      return EnConnection.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error getting en connection: $e');
      rethrow;
    }
  }
}

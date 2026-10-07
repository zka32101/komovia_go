import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import 'friend_service.dart';
import 'spectator_service.dart';

final _logger = Logger();

/// 運命の一手通知 - 対局中の劇的な瞬間をAIが検出し、フレンドにシェアする
class FatefulMoveService {
  final FirebaseFirestore _firestore;
  final FriendService _friendService;
  final SpectatorService _spectatorService;

  /// この石数以上を一手で捕獲したら「大石を仕留めた一手」
  static const int bigCaptureThreshold = 5;

  FatefulMoveService(this._firestore, this._friendService, this._spectatorService);

  /// 直前の手による捕獲石数から、運命の一手かどうかを検出する
  FatefulMoveType? detectFatefulMoveType({
    required int stonesCaptured,
    required int moveNumber,
    required bool wasKoResolved,
  }) {
    if (stonesCaptured >= bigCaptureThreshold) {
      return FatefulMoveType.bigCapture;
    }
    if (wasKoResolved && stonesCaptured > 0) {
      return FatefulMoveType.koFight;
    }
    if (stonesCaptured >= 2 && moveNumber < 80) {
      return FatefulMoveType.tesuji;
    }
    if (stonesCaptured >= 2) {
      return FatefulMoveType.lifeAndDeath;
    }
    return null;
  }

  Future<FatefulMove> saveFatefulMove({
    required String uid,
    required String displayName,
    String? gameId,
    required int moveNumber,
    required int boardSize,
    required FatefulMoveType type,
    required int stonesCaptured,
  }) async {
    try {
      final docRef = _firestore.collection('fateful_moves').doc();
      final move = FatefulMove(
        id: docRef.id,
        uid: uid,
        displayName: displayName,
        gameId: gameId,
        moveNumber: moveNumber,
        boardSize: boardSize,
        type: type,
        stonesCaptured: stonesCaptured,
        detectedAt: DateTime.now(),
        sharedWithFriends: false,
      );
      await docRef.set(move.toFirestore());
      _logger.i('Saved fateful move ${docRef.id}: ${type.getDisplayName()}');
      return move;
    } catch (e) {
      _logger.e('Error saving fateful move: $e');
      rethrow;
    }
  }

  /// 運命の一手をフレンド全員に通知する
  Future<void> shareFatefulMoveWithFriends(FatefulMove move) async {
    try {
      final friends = await _friendService.getFriends(uid: move.uid);
      for (final friend in friends) {
        await _spectatorService.sendSpectatorNotification(
          uid: friend.uid,
          title: '${move.displayName} さんに運命の一手！',
          body: '${move.type.getDisplayName()}（${move.stonesCaptured}子捕獲）',
          hostUid: move.uid,
          hostDisplayName: move.displayName,
        );
      }
      await _firestore
          .collection('fateful_moves')
          .doc(move.id)
          .update({'sharedWithFriends': true});
      _logger.i('Shared fateful move ${move.id} with ${friends.length} friends');
    } catch (e) {
      _logger.e('Error sharing fateful move with friends: $e');
      rethrow;
    }
  }

  Future<List<FatefulMove>> getFatefulMoves(String uid, {int limit = 50}) async {
    try {
      final snapshots = await _firestore
          .collection('fateful_moves')
          .where('uid', isEqualTo: uid)
          .orderBy('detectedAt', descending: true)
          .limit(limit)
          .get();
      return snapshots.docs.map((doc) => FatefulMove.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting fateful moves: $e');
      rethrow;
    }
  }
}

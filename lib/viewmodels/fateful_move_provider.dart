import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';
import 'friend_provider.dart';
import 'spectator_provider.dart';

final _logger = Logger();

final fatefulMoveServiceProvider = Provider((ref) {
  final friendService = ref.watch(friendServiceProvider);
  final spectatorService = ref.watch(spectatorServiceProvider);
  return FatefulMoveService(FirebaseFirestore.instance, friendService, spectatorService);
});

final fatefulMovesProvider =
    FutureProvider.family<List<FatefulMove>, String>((ref, uid) async {
  final service = ref.watch(fatefulMoveServiceProvider);
  try {
    final moves = await service.getFatefulMoves(uid);
    _logger.i('Fetched ${moves.length} fateful moves for $uid');
    return moves;
  } catch (e) {
    _logger.e('Error fetching fateful moves: $e');
    rethrow;
  }
});

final detectAndShareFatefulMoveProvider = Provider((ref) {
  return (
    String uid,
    String displayName,
    String? gameId,
    int moveNumber,
    int boardSize,
    int stonesCaptured,
    bool wasKoResolved,
  ) async {
    final service = ref.watch(fatefulMoveServiceProvider);
    try {
      final type = service.detectFatefulMoveType(
        stonesCaptured: stonesCaptured,
        moveNumber: moveNumber,
        wasKoResolved: wasKoResolved,
      );
      if (type == null) return null;

      final move = await service.saveFatefulMove(
        uid: uid,
        displayName: displayName,
        gameId: gameId,
        moveNumber: moveNumber,
        boardSize: boardSize,
        type: type,
        stonesCaptured: stonesCaptured,
      );
      await service.shareFatefulMoveWithFriends(move);
      _logger.i('Detected and shared fateful move: ${type.getDisplayName()}');
      return move;
    } catch (e) {
      _logger.e('Error detecting/sharing fateful move: $e');
      rethrow;
    }
  };
});

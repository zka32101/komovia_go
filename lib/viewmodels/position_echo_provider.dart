import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';

final _logger = Logger();

final positionEchoServiceProvider = Provider((ref) {
  return PositionEchoService(FirebaseFirestore.instance);
});

final historicalEchoesProvider =
    FutureProvider.family<List<PositionEcho>, String>((ref, uid) async {
  final service = ref.watch(positionEchoServiceProvider);
  try {
    final echoes = await service.getHistoricalEchoes(uid);
    _logger.i('Fetched ${echoes.length} historical echoes for $uid');
    return echoes;
  } catch (e) {
    _logger.e('Error fetching historical echoes: $e');
    rethrow;
  }
});

final usersAtSamePositionProvider =
    FutureProvider.family<List<PositionEcho>, ({String positionHash, String? excludeUid})>(
        (ref, params) async {
  final service = ref.watch(positionEchoServiceProvider);
  try {
    final echoes = await service.getUsersAtSamePosition(
      params.positionHash,
      excludeUid: params.excludeUid,
    );
    _logger.i('Fetched ${echoes.length} users at position ${params.positionHash.substring(0, 12)}...');
    return echoes;
  } catch (e) {
    _logger.e('Error fetching users at same position: $e');
    rethrow;
  }
});

final recordPositionReachedProvider = Provider((ref) {
  return (String uid, String displayName, BoardState board, int moveNumber) async {
    final service = ref.watch(positionEchoServiceProvider);
    try {
      final echo = await service.recordPositionReached(
        uid: uid,
        displayName: displayName,
        board: board,
        moveNumber: moveNumber,
      );
      if (echo.matchesHistoricalGame) {
        _logger.i('User $uid echoed historical game: ${echo.kifuTitle}');
      }
      return echo;
    } catch (e) {
      _logger.e('Error recording position reached: $e');
      rethrow;
    }
  };
});

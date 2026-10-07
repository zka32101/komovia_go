import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';

final _logger = Logger();

final concurrentSessionServiceProvider = Provider((ref) {
  return ConcurrentSessionService(FirebaseFirestore.instance);
});

final concurrentPlayersProvider =
    FutureProvider.family<List<ActivePlaySession>, String?>((ref, excludeUid) async {
  final service = ref.watch(concurrentSessionServiceProvider);
  try {
    final players = await service.getConcurrentPlayers(excludeUid: excludeUid);
    _logger.i('Fetched ${players.length} concurrent players');
    return players;
  } catch (e) {
    _logger.e('Error fetching concurrent players: $e');
    rethrow;
  }
});

final concurrentPlayerCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(concurrentSessionServiceProvider);
  try {
    return await service.getConcurrentPlayerCount();
  } catch (e) {
    _logger.e('Error fetching concurrent player count: $e');
    rethrow;
  }
});

final startPlaySessionProvider = Provider((ref) {
  return (String uid, String displayName, int boardSize, String gameType) async {
    final service = ref.watch(concurrentSessionServiceProvider);
    try {
      await service.startSession(
        uid: uid,
        displayName: displayName,
        boardSize: boardSize,
        gameType: gameType,
      );
      _logger.i('Started play session: $uid');
    } catch (e) {
      _logger.e('Error starting play session: $e');
      rethrow;
    }
  };
});

final sendPlaySessionHeartbeatProvider = Provider((ref) {
  return (String uid) async {
    final service = ref.watch(concurrentSessionServiceProvider);
    try {
      await service.heartbeat(uid);
    } catch (e) {
      _logger.e('Error sending play session heartbeat: $e');
      rethrow;
    }
  };
});

final endPlaySessionProvider = Provider((ref) {
  return (String uid) async {
    final service = ref.watch(concurrentSessionServiceProvider);
    try {
      await service.endSession(uid);
      _logger.i('Ended play session: $uid');
    } catch (e) {
      _logger.e('Error ending play session: $e');
      rethrow;
    }
  };
});

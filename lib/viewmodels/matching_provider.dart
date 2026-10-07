import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';

final _logger = Logger();

final matchingServiceProvider = Provider((ref) {
  return MatchingService(FirebaseFirestore.instance);
});

final matchHistoryProvider =
    FutureProvider.family<List<MatchResult>, String>((ref, uid) async {
  final service = ref.watch(matchingServiceProvider);
  try {
    final matches = await service.getMatchHistory(uid);
    _logger.i('Fetched ${matches.length} matches for $uid');
    return matches;
  } catch (e) {
    _logger.e('Error fetching match history: $e');
    rethrow;
  }
});

final joinMatchmakingQueueProvider = Provider((ref) {
  return (String uid, String displayName, int rating, int boardSize) async {
    final service = ref.watch(matchingServiceProvider);
    try {
      await service.joinQueue(
        uid: uid,
        displayName: displayName,
        rating: rating,
        boardSize: boardSize,
      );
      _logger.i('Joined matchmaking queue: $uid');
    } catch (e) {
      _logger.e('Error joining matchmaking queue: $e');
      rethrow;
    }
  };
});

final leaveMatchmakingQueueProvider = Provider((ref) {
  return (String uid) async {
    final service = ref.watch(matchingServiceProvider);
    try {
      await service.leaveQueue(uid);
      _logger.i('Left matchmaking queue: $uid');
    } catch (e) {
      _logger.e('Error leaving matchmaking queue: $e');
      rethrow;
    }
  };
});

final findMatchProvider = Provider((ref) {
  return (String uid, String displayName, int rating, int boardSize) async {
    final service = ref.watch(matchingServiceProvider);
    try {
      final match = await service.findMatch(
        uid: uid,
        displayName: displayName,
        rating: rating,
        boardSize: boardSize,
      );
      if (match != null) {
        _logger.i('Match found for $uid: ${match.id}');
      }
      return match;
    } catch (e) {
      _logger.e('Error finding match: $e');
      rethrow;
    }
  };
});

final attachGameToMatchProvider = Provider((ref) {
  return (String matchId, String gameId) async {
    final service = ref.watch(matchingServiceProvider);
    try {
      await service.attachGameToMatch(matchId, gameId);
      _logger.i('Attached game to match: $matchId');
    } catch (e) {
      _logger.e('Error attaching game to match: $e');
      rethrow;
    }
  };
});

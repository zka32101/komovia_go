import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';

final _logger = Logger();

final enScoreServiceProvider = Provider((ref) {
  return EnScoreService(FirebaseFirestore.instance);
});

final enConnectionsProvider =
    FutureProvider.family<List<EnConnection>, String>((ref, uid) async {
  final service = ref.watch(enScoreServiceProvider);
  try {
    final connections = await service.getEnConnections(uid);
    _logger.i('Fetched ${connections.length} en connections for $uid');
    return connections;
  } catch (e) {
    _logger.e('Error fetching en connections: $e');
    rethrow;
  }
});

final enConnectionProvider = FutureProvider.family<EnConnection?,
    ({String uid, String friendUid})>((ref, params) async {
  final service = ref.watch(enScoreServiceProvider);
  try {
    return await service.getEnConnection(params.uid, params.friendUid);
  } catch (e) {
    _logger.e('Error fetching en connection: $e');
    rethrow;
  }
});

final calculateEnScoreProvider = Provider((ref) {
  return (String uid, String friendUid, String friendDisplayName, DateTime friendshipStartedAt) async {
    final service = ref.watch(enScoreServiceProvider);
    try {
      final connection = await service.calculateEnScore(
        uid: uid,
        friendUid: friendUid,
        friendDisplayName: friendDisplayName,
        friendshipStartedAt: friendshipStartedAt,
      );
      _logger.i('Calculated en score: ${connection.score} (${connection.level})');
      return connection;
    } catch (e) {
      _logger.e('Error calculating en score: $e');
      rethrow;
    }
  };
});

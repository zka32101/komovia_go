import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

final _logger = Logger();

// ================== KIFU LIBRARY ==================

/// Singleton instance of FirestoreService (shared)
final kifuFirestoreProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Kifu library - all available games to study
final kifuLibraryProvider = FutureProvider<List<KifuLibrary>>((ref) async {
  _logger.i('Fetching kifu library');

  final firestoreService = ref.watch(kifuFirestoreProvider);
  try {
    final games = await firestoreService.getCopyrightFreeKifus();
    _logger.i('✅ Kifu library fetched: ${games.length} games');
    return games;
  } catch (e) {
    _logger.e('❌ Failed to fetch kifu library: $e');
    return []; // Return empty list on error
  }
});

/// Currently selected kifu game
final selectedKifuProvider = StateProvider<KifuLibrary?>((ref) {
  return null;
});

/// Observation progress tracking
final kifuObservationProgressProvider = StateProvider<Map<String, int>>((ref) {
  return {}; // game_id -> move_number
});

/// Records how far the user watched into a kifu. Plain action (same
/// reasoning as saveGameRecordProvider/recordPuzzleAttemptProvider) so
/// repeated calls always write, rather than a FutureProvider.family
/// silently returning a cached result for a previous game/rate.
final saveObservationLogProvider = Provider<
    Future<String> Function({
      required String uid,
      required String kifuId,
      required double completedRate,
    })>((ref) {
  return ({required uid, required kifuId, required completedRate}) async {
    _logger.i('Saving observation log: uid=$uid, kifuId=$kifuId, rate=$completedRate');

    final firestoreService = ref.read(kifuFirestoreProvider);
    final log = ObservationLog(
      id: '', // Firestore will auto-generate
      uid: uid,
      kifuId: kifuId,
      watchedAt: DateTime.now(),
      completedRate: completedRate.clamp(0.0, 1.0),
    );

    try {
      final logId = await firestoreService.saveObservationLog(log);
      _logger.i('✅ Observation log saved: $logId');
      return logId;
    } catch (e) {
      _logger.e('❌ Failed to save observation log: $e');
      rethrow;
    }
  };
});

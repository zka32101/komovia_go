import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/config/avatar_frames.dart';
import 'package:komovia_go/services/index.dart';
import 'package:logger/logger.dart';

import 'auth_provider.dart';
import 'en_score_provider.dart';
import 'leaderboard_provider.dart';
import 'tsume_go_provider.dart';

final _logger = Logger();

/// Gathers the already-tracked stats avatar frame unlocks derive from
/// (allTime rating/tournament leaderboard entries, games played, tsume-go
/// streak, best En score). Every source is best-effort: a failed read
/// counts as "not met" rather than erroring the whole picker.
final frameStatsProvider = FutureProvider.autoDispose<FrameStats?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final uid = user.uid;

  Future<T> safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } catch (e) {
      _logger.w('Frame stat read failed (treated as unmet): $e');
      return fallback;
    }
  }

  final rating = await safe<LeaderboardEntry?>(
    () => ref.read(userLeaderboardRankProvider((
      uid: uid,
      period: LeaderboardPeriod.allTime,
      type: LeaderboardType.rating,
    )).future),
    null,
  );
  final tournament = await safe<LeaderboardEntry?>(
    () => ref.read(userLeaderboardRankProvider((
      uid: uid,
      period: LeaderboardPeriod.allTime,
      type: LeaderboardType.tournament,
    )).future),
    null,
  );
  final streak = await safe<int>(
      () => ref.read(tsumeGoStreakProvider(uid).future), 0);
  final maxEn = await safe<int>(() async {
    final conns = await ref.read(enScoreServiceProvider).getEnConnections(uid);
    return conns.fold<int>(0, (m, c) => c.score > m ? c.score : m);
  }, 0);

  return FrameStats(
    rating: rating?.rating,
    gamesPlayed: user.gamesPlayedCount,
    wins: rating?.wins ?? 0,
    tournamentWins: tournament?.tournamentWins ?? 0,
    tsumegoStreak: streak,
    maxEnScore: maxEn,
    earnedFrameIds: user.earnedFrameIds.toSet(),
  );
});

/// Current user's unlocked frame ids (recomputed on read). Newly met
/// sticky frames (see `kStickyFrameIds`) are persisted to
/// `User.earnedFrameIds` best-effort so they survive the stat dropping.
final unlockedFrameIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final stats = await ref.watch(frameStatsProvider.future);
  if (stats == null) return const {};
  final unlocked = computeUnlockedFrameIds(stats);

  final newlySticky = unlocked
      .where((id) =>
          kStickyFrameIds.contains(id) && !stats.earnedFrameIds.contains(id))
      .toList();
  if (newlySticky.isNotEmpty) {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      try {
        final updated = user.copyWith(
          earnedFrameIds: {...user.earnedFrameIds, ...newlySticky}.toList(),
        );
        await FirestoreService().saveUser(updated);
        ref.read(authServiceProvider).refreshCachedUser(updated);
      } catch (e) {
        _logger.w('Failed to persist earned frames (non-fatal): $e');
      }
    }
  }
  return unlocked;
});

/// Persists the selected frame id (null = no frame). Same pattern as
/// [updateAvatarProvider].
final updateFrameProvider = Provider<Future<void> Function(String?)>((ref) {
  return (frameId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('No user logged in');
    final updated = user.copyWith(frameId: frameId, updatedAt: DateTime.now());
    await FirestoreService().saveUser(updated);
    ref.read(authServiceProvider).refreshCachedUser(updated);
    ref.invalidate(currentUserProvider);
  };
});

/// The frame to render around the current user's avatar right now, or
/// null. A stored selection that's no longer unlocked is ignored (not
/// cleared), so a rank frame reappears if the rank is regained.
final displayedFrameProvider = Provider.autoDispose<AvatarFrame?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user?.frameId == null) return null;
  final unlocked = ref.watch(unlockedFrameIdsProvider).valueOrNull ?? const {};
  return resolveDisplayedFrame(user!.frameId, unlocked);
});

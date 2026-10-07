import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/leaderboard.dart';
import 'package:komovia_go/services/leaderboard_service.dart';

final _logger = Logger();

/// Leaderboard Service プロバイダー
final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});

/// 現在のランキング期間（状態）
final leaderboardPeriodProvider = StateProvider<LeaderboardPeriod>((ref) {
  return LeaderboardPeriod.allTime;
});

/// 現在のランキングタイプ（状態）
final leaderboardTypeProvider = StateProvider<LeaderboardType>((ref) {
  return LeaderboardType.rating;
});

/// ランキング一覧を取得（期間・タイプ別）
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>,
    ({LeaderboardPeriod period, LeaderboardType type, int limit})>((
  ref,
  params,
) async {
  _logger.i('Loading leaderboard: period=${params.period}, type=${params.type}');
  final service = ref.watch(leaderboardServiceProvider);
  
  try {
    final entries = await service.getLeaderboard(
      period: params.period,
      type: params.type,
      limit: params.limit,
    );
    _logger.i('✅ Leaderboard loaded: ${entries.length} entries');
    return entries;
  } catch (e) {
    _logger.e('❌ Failed to load leaderboard: $e');
    rethrow;
  }
});

/// 現在のランキングを取得（選択中の期間・タイプ）
final currentLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final type = ref.watch(leaderboardTypeProvider);
  
  return ref.watch(leaderboardProvider((period: period, type: type, limit: 100)).future);
});

/// ユーザーのランキング順位を取得
final userLeaderboardRankProvider = FutureProvider.family<LeaderboardEntry?,
    ({String uid, LeaderboardPeriod period, LeaderboardType type})>((
  ref,
  params,
) async {
  _logger.i('Fetching user rank: uid=${params.uid}');
  final service = ref.watch(leaderboardServiceProvider);
  
  try {
    final rank = await service.getUserRank(
      uid: params.uid,
      period: params.period,
      type: params.type,
    );
    return rank;
  } catch (e) {
    _logger.e('❌ Failed to fetch user rank: $e');
    return null;
  }
});

/// ユーザーの現在のランク（選択中の期間・タイプ）
final currentUserRankProvider = FutureProvider.family<LeaderboardEntry?,
    String>((ref, uid) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final type = ref.watch(leaderboardTypeProvider);
  
  return ref.watch(
    userLeaderboardRankProvider((uid: uid, period: period, type: type)).future,
  );
});

/// ランキングを更新
final updateLeaderboardProvider = Provider<
    Future<void> Function({
      required LeaderboardPeriod period,
      required LeaderboardType type,
      required List<LeaderboardEntry> entries,
    })>((ref) {
  final service = ref.read(leaderboardServiceProvider);

  return ({
    required LeaderboardPeriod period,
    required LeaderboardType type,
    required List<LeaderboardEntry> entries,
  }) async {
    _logger.i('Updating leaderboard');
    try {
      await service.updateLeaderboard(
        period: period,
        type: type,
        entries: entries,
      );
      _logger.i('✅ Leaderboard updated');
    } catch (e) {
      _logger.e('❌ Failed to update leaderboard: $e');
      rethrow;
    }
  };
});

/// ユーザースコアを更新
final updateUserScoreProvider = Provider<
    Future<void> Function({
      required String uid,
      required String displayName,
      required LeaderboardPeriod period,
      required LeaderboardType type,
      required int rating,
      required int gamesPlayed,
      required int wins,
      required int puzzlesSolved,
    })>((ref) {
  final service = ref.read(leaderboardServiceProvider);

  return ({
    required String uid,
    required String displayName,
    required LeaderboardPeriod period,
    required LeaderboardType type,
    required int rating,
    required int gamesPlayed,
    required int wins,
    required int puzzlesSolved,
  }) async {
    _logger.i('Updating user score');
    try {
      await service.updateUserScore(
        uid: uid,
        displayName: displayName,
        period: period,
        type: type,
        rating: rating,
        gamesPlayed: gamesPlayed,
        wins: wins,
        puzzlesSolved: puzzlesSolved,
      );
      _logger.i('✅ User score updated');
    } catch (e) {
      _logger.e('❌ Failed to update user score: $e');
      rethrow;
    }
  };
});

/// ユーザーの統計を安全にインクリメント/更新する（PvP対局結果・詰碁の
/// 正解など、他の呼び出し元が把握していないフィールドをゼロで
/// 上書きしないための、updateUserScoreProviderの代替）
final incrementUserStatsProvider = Provider<
    Future<void> Function({
      required String uid,
      required String displayName,
      required LeaderboardPeriod period,
      required LeaderboardType type,
      int? newRating,
      int gamesPlayedDelta,
      int winsDelta,
      int puzzlesSolvedDelta,
      int achievementsUnlockedDelta,
      int tournamentWinsDelta,
    })>((ref) {
  final service = ref.read(leaderboardServiceProvider);

  return ({
    required String uid,
    required String displayName,
    required LeaderboardPeriod period,
    required LeaderboardType type,
    int? newRating,
    int gamesPlayedDelta = 0,
    int winsDelta = 0,
    int puzzlesSolvedDelta = 0,
    int achievementsUnlockedDelta = 0,
    int tournamentWinsDelta = 0,
  }) async {
    _logger.i('Incrementing user stats');
    try {
      await service.incrementUserStats(
        uid: uid,
        displayName: displayName,
        period: period,
        type: type,
        newRating: newRating,
        gamesPlayedDelta: gamesPlayedDelta,
        winsDelta: winsDelta,
        puzzlesSolvedDelta: puzzlesSolvedDelta,
        achievementsUnlockedDelta: achievementsUnlockedDelta,
        tournamentWinsDelta: tournamentWinsDelta,
      );
      _logger.i('✅ User stats incremented');
    } catch (e) {
      _logger.e('❌ Failed to increment user stats: $e');
      rethrow;
    }
  };
});

/// ランキングをリセット
final resetLeaderboardProvider = Provider<
    Future<void> Function({
      required LeaderboardPeriod period,
      required LeaderboardType type,
    })>((ref) {
  final service = ref.read(leaderboardServiceProvider);

  return ({
    required LeaderboardPeriod period,
    required LeaderboardType type,
  }) async {
    _logger.w('Resetting leaderboard');
    try {
      await service.resetLeaderboard(
        period: period,
        type: type,
      );
      _logger.i('✅ Leaderboard reset');
    } catch (e) {
      _logger.e('❌ Failed to reset leaderboard: $e');
      rethrow;
    }
  };
});

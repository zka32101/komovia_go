import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/utils/ai_rating.dart';
import 'package:komovia_go/utils/go_rank.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/stats_chart_widget.dart';

/// 成長トラッキング画面 - 「負けて悔しくても続けられて、着実に強くなる
/// ことが実感できる」というシリーズ全体のコンセプトに基づき、現在の
/// レーティング・棋力（formatGoRank）・過去の対局を通じたレーティング
/// 推移を1画面にまとめる。
///
/// レーティング自体はgame_provider.dartの_updateAiGameRatingが対局
/// 終了ごとにLeaderboardEntry(rating)へ書き込んでおり、ここでは単に
/// それを表示する。推移グラフは各GameRecordに保存されたratingAfterを
/// 時系列で並べたもの - 新しい対局ほど新しいratingAfterを持つので、
/// それ以前にratingAfterが無い(nullの)古い対局だけはai_rating.dartの
/// 同じ式で近似値を遡及計算して穴埋めする（_updateAiGameRating導入前の
/// 対局向けの後方互換措置）。
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text(l10n.growthScreenTitle),
        backgroundColor: AppColors.sumi,
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.loginRequiredMessage,
                style: TextStyle(color: AppColors.washiDim),
              ),
            )
          : _GrowthBody(uid: uid),
    );
  }
}

class _GrowthBody extends ConsumerWidget {
  final String uid;

  const _GrowthBody({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rankAsync = ref.watch(userLeaderboardRankProvider((
      uid: uid,
      period: LeaderboardPeriod.allTime,
      type: LeaderboardType.rating,
    )));
    final recordsAsync = ref.watch(userGameRecordsProvider(uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rankAsync.when(
            data: (entry) => _buildCurrentRatingCard(context, entry?.rating ?? 1200),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildCurrentRatingCard(context, 1200),
          ),
          const SizedBox(height: 20),
          recordsAsync.when(
            data: (records) => _buildTrendSection(
              context,
              records,
              entry: rankAsync.valueOrNull,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text(
              l10n.growthTrendUnavailableMessage,
              style: TextStyle(color: AppColors.washiDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRatingCard(BuildContext context, int rating) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growthCurrentRatingLabel,
              style: TextStyle(color: AppColors.washiDim, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatGoRank(rating),
                  style: TextStyle(
                    color: AppColors.kin,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '($rating)',
                  style: TextStyle(color: AppColors.washiDim, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSection(
    BuildContext context,
    List<GameRecord> records, {
    required LeaderboardEntry? entry,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (records.isEmpty) {
      return Card(
        color: AppColors.sumiSurface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.growthNoGamesMessage,
            style: TextStyle(color: AppColors.washiDim),
          ),
        ),
      );
    }

    // userGameRecordsProvider returns newest-first; the chart reads
    // left-to-right as oldest-to-newest, so reverse it here.
    final chronological = records.reversed.toList();
    final ratings = _reconstructRatingTrend(chronological);

    // "総対局数"/"勝率" はライフタイム累計を謳っているが、userGameRecordsProvider
    // 自体は直近20局にlimitされている（game_provider.dart）。そのため、既に
    // このUIが取得済みの非cappedなLeaderboardEntry集計（gamesPlayed/winRate）
    // があればそちらを使い、無い場合のみ（未参戦等でエントリ未生成）直近分を
    // フォールバックとして表示する。
    final totalGames = entry?.gamesPlayed ?? records.length;
    final winRatePercent = entry != null
        ? (entry.winRate * 100).round()
        : (records.where((r) => r.result == GameResult.playerWin).length /
                records.length *
                100)
            .round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                context,
                label: l10n.growthTotalGamesLabel,
                value: '$totalGames',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                context,
                label: l10n.growthWinRateLabel,
                value: '$winRatePercent%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WinRateLineChartWidget(
          values: ratings.map((r) => r.toDouble()).toList(),
          title: l10n.growthRatingTrendTitle,
          daysBack: chronological.length,
        ),
        const SizedBox(height: 16),
        _buildEncouragement(context, ratings),
      ],
    );
  }

  Widget _buildStatTile(BuildContext context, {required String label, required String value}) {
    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: AppColors.washi, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// 直近(最大10局)のレーティング推移の符号から、励ましのメッセージを
  /// 選ぶ。「負けても成長を実感できる」というコンセプトに沿い、直近が
  /// 下降気味でも突き放さず「続ければ伸びる」トーンを保つ。
  Widget _buildEncouragement(BuildContext context, List<int> ratings) {
    final l10n = AppLocalizations.of(context)!;
    final recent = ratings.length > 10 ? ratings.sublist(ratings.length - 10) : ratings;
    final netChange = recent.length >= 2 ? recent.last - recent.first : 0;

    final String message;
    if (recent.length < 3) {
      message = l10n.growthEncouragementStarting;
    } else if (netChange > 0) {
      message = l10n.growthEncouragementRising;
    } else {
      message = l10n.growthEncouragementSteady;
    }

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.eco, color: AppColors.wakatake),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: AppColors.washi)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 時系列順(古い→新しい)の対局リストから、各対局終了時点でのレーティング
/// 推移を復元する。ratingAfterが保存されている対局はそれをそのまま使い、
/// 保存されていない古い対局（_updateAiGameRating導入前のもの、または
/// ベストエフォート書き込みが失敗したもの）は、直前の既知のレーティング
/// から同じcomputeRatingDeltaの式で遡及計算して埋める。
List<int> _reconstructRatingTrend(List<GameRecord> chronological) {
  final result = <int>[];
  var runningRating = 1200;
  for (final record in chronological) {
    if (record.ratingAfter != null) {
      runningRating = record.ratingAfter!;
    } else {
      final delta = computeRatingDelta(
        currentRating: runningRating,
        aiLevel: record.aiLevel,
        result: record.result,
      );
      runningRating += delta;
    }
    result.add(runningRating);
  }
  return result;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/index.dart';
import '../../viewmodels/index.dart';
import '../widgets/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// Analytics dashboard screen
class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // currentUserProvider is a plain Provider<User?> (not an AsyncValue).
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.analyticsDashboardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: currentUser == null
          ? Center(child: Text(l10n.loginRequiredMessage))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Summary cards
                  _buildSummarySection(l10n, ref, currentUser.uid),

                  const SizedBox(height: 24),

                  // Win rate by board size
                  _buildWinRateByBoardSize(l10n, ref, currentUser.uid),

                  const SizedBox(height: 24),

                  // Win rate by AI level
                  _buildWinRateByAiLevel(l10n, ref, currentUser.uid),

                  const SizedBox(height: 24),

                  // Achievements
                  _buildAchievementsSection(l10n, ref, currentUser.uid),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection(AppLocalizations l10n, WidgetRef ref, String userId) {
    final statsAsync = ref.watch(userStatisticsProvider(userId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: statsAsync.when(
        data: (stats) {
          if (stats == null) {
            return Center(
              child: Text(l10n.noStatsDataMessage,
                  style: TextStyle(color: AppColors.washiDim)),
            );
          }

          return Column(
            children: [
              // Main stats grid
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    '${stats.totalGamesPlayed}',
                    l10n.gamesCountStatLabel,
                    AppColors.aiLight,
                  ),
                  _buildStatCard(
                    '${stats.totalWins}',
                    l10n.winsStatLabel,
                    AppColors.wakatake,
                  ),
                  _buildStatCard(
                    '${stats.winRate.toStringAsFixed(1)}%',
                    l10n.winRateStatLabel,
                    AppColors.kin,
                  ),
                  _buildStatCard(
                    l10n.avgDurationMinutesValue(stats.averageGameDuration.toStringAsFixed(0)),
                    l10n.avgTimeStatLabel,
                    AppColors.fuji,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Favorite info
              Card(
                color: AppColors.sumiSurface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(l10n.favoriteModeLabel,
                              style: TextStyle(color: AppColors.washiDim,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(stats.favoriteGameMode,
                              style: const TextStyle(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                      Column(
                        children: [
                          Text(l10n.favoriteLevelLabel,
                              style: TextStyle(color: AppColors.washiDim,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Lv${stats.favoriteAiLevel}',
                              style: const TextStyle(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                      Column(
                        children: [
                          Text(l10n.favoriteSizeLabel,
                              style: TextStyle(color: AppColors.washiDim,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${stats.favoriteBoardSize}×${stats.favoriteBoardSize}',
                              style: const TextStyle(
                                color: AppColors.washi,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: AppColors.washiDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinRateByBoardSize(AppLocalizations l10n, WidgetRef ref, String userId) {
    final winRateAsync = ref.watch(winRateByBoardSizeProvider(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: winRateAsync.when(
        data: (winRates) {
          return WinRateBarChartWidget(
            data: winRates,
            title: l10n.winRateByBoardSizeTitle,
            xAxisLabel: l10n.boardSizeAxisLabel,
            yAxisLabel: l10n.winRatePercentAxisLabel,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Card(
          color: AppColors.sumiSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.errorPrefix('$err'),
                style: TextStyle(color: AppColors.shuLight)),
          ),
        ),
      ),
    );
  }

  Widget _buildWinRateByAiLevel(AppLocalizations l10n, WidgetRef ref, String userId) {
    final winRateAsync = ref.watch(winRateByAiLevelProvider(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: winRateAsync.when(
        data: (winRates) {
          // Convert Map<int, double> to Map<String, double>
          final chartData = <String, double>{
            for (var entry in winRates.entries) 'Lv${entry.key}': entry.value
          };

          return WinRateBarChartWidget(
            data: chartData,
            title: l10n.winRateByAiLevelTitle,
            xAxisLabel: l10n.aiLevelAxisLabel,
            yAxisLabel: l10n.winRatePercentAxisLabel,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Card(
          color: AppColors.sumiSurface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.errorPrefix('$err'),
                style: TextStyle(color: AppColors.shuLight)),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(AppLocalizations l10n, WidgetRef ref, String userId) {
    final achievementsAsync = ref.watch(unlockedAchievementsProvider(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.achievementsTitle,
            style: TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          achievementsAsync.when(
            data: (achievements) {
              if (achievements.isEmpty) {
                return Card(
                  color: AppColors.sumiSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.noAchievementsMessage,
                        style: TextStyle(color: AppColors.washiDim)),
                  ),
                );
              }

              return AchievementGridWidget(
                achievements: achievements,
                crossAxisCount: 3,
                onAchievementTap: () {
                  // Future: Show achievement detail dialog
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text(l10n.errorPrefix('$err')),
          ),
        ],
      ),
    );
  }
}

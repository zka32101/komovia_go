import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/index.dart';
import '../../viewmodels/index.dart';
import '../widgets/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// 実績の一覧画面。それまでトースト(対局直後のみ)・通知ベル・
/// AnalyticsDashboardScreen内の小さなセクション(解除済みのみ、進捗や
/// 未解除分は表示されない)でしか実績に触れる機会が無く、全実績を
/// 一覧できる専用画面が存在しなかった（見出し③の修正）。
/// 'achievement'通知のタップ先、HomeScreen/AnalyticsDashboardScreenから
/// 「すべて見る」で遷移する先として使う。
class AchievementsScreen extends ConsumerWidget {
  final String uid;

  const AchievementsScreen({Key? key, required this.uid}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unlockedAsync = ref.watch(unlockedAchievementsProvider(uid));
    final progressAsync = ref.watch(achievementProgressProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.achievementsTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: unlockedAsync.when(
        data: (unlocked) {
          final unlockedIds = unlocked.map((a) => a.id).toSet();
          return progressAsync.when(
            data: (progressList) {
              final locked = progressList
                  .where((p) => !unlockedIds.contains(p.achievement.id))
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.achievementsUnlockedSectionTitle,
                    style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (unlocked.isEmpty)
                    Card(
                      color: AppColors.sumiSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.noAchievementsMessage, style: const TextStyle(color: AppColors.washiDim)),
                      ),
                    )
                  else
                    AchievementGridWidget(achievements: unlocked, crossAxisCount: 3),
                  const SizedBox(height: 24),
                  if (locked.isNotEmpty) ...[
                    Text(
                      l10n.achievementsLockedSectionTitle,
                      style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...locked.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AchievementProgressWidget(
                          achievement: p.achievement,
                          progress: p.progress,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }
}

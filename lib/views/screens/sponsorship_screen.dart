import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// SponsorshipScreen - スポンサーシップ管理
class SponsorshipScreen extends ConsumerWidget {
  const SponsorshipScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building SponsorshipScreen');
    final l10n = AppLocalizations.of(context)!;

    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.sumi,
        appBar: AppBar(
          title: Text(l10n.sponsorshipTitle),
          backgroundColor: AppColors.sumi,
        ),
        body: Center(
          child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
        ),
      );
    }
    final uid = currentUser.uid;

    final sponsorInfo = ref.watch(sponsorInfoProvider(uid));
    final incomingSponsors = ref.watch(incomingSponsorsProvider(uid));
    final notifications = ref.watch(sponsorshipNotificationsProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.sponsorshipTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
      ),
      body: sponsorInfo.when(
        data: (info) {
          if (info == null) {
            return _buildEmptyState(context, l10n);
          }
          return _buildSponsorshipView(
            context,
            ref,
            l10n,
            uid,
            info,
            incomingSponsors,
            notifications,
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
          ),
        ),
        error: (error, stack) => Center(
          child: Text(l10n.errorPrefix('$error'), style: const TextStyle(color: AppColors.washi)),
        ),
      ),
    );
  }

  /// 空状態
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: AppColors.kin,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.sponsorshipTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.sponsorshipNotConfiguredMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// スポンサーシップ表示
  Widget _buildSponsorshipView(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    SponsorInfo info,
    AsyncValue<List<SponsorshipRecord>> incomingSponsors,
    AsyncValue<List<SponsorshipNotification>> notifications,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 統計情報
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.kin, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.kin.withAlpha(50),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sponsorshipStatsTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.kin,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      context,
                      '${info.totalSponsorshipCount}',
                      l10n.sponsorCountLabel,
                      AppColors.kin,
                    ),
                    _buildStatColumn(
                      context,
                      '\$${(info.totalMonthlyUSD / 100).toStringAsFixed(2)}',
                      l10n.monthlyIncomeLabel,
                      AppColors.wakatake,
                    ),
                    _buildStatColumn(
                      context,
                      '${info.availableTiers.length}',
                      l10n.tierCountLabel,
                      AppColors.aiLight,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // スポンサー一覧
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sponsorListTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                incomingSponsors.when(
                  data: (sponsors) {
                    if (sponsors.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.noSponsorsMessage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.washiDim,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sponsors.length,
                      itemBuilder: (context, index) {
                        final sponsor = sponsors[index];
                        return _buildSponsorCard(context, sponsor);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
                    ),
                  ),
                  error: (error, stack) => Text(
                    l10n.errorPrefix('$error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // 通知
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.recentActivityTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                notifications.when(
                  data: (notifs) {
                    if (notifs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.noActivityMessage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.washiDim,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notifs.length.clamp(0, 5), // 最新5件
                      itemBuilder: (context, index) {
                        final notif = notifs[index];
                        return _buildNotificationCard(context, l10n, notif);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
                    ),
                  ),
                  error: (error, stack) => Text(
                    l10n.errorPrefix('$error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // ティア管理ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addTierButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kin,
              ),
              onPressed: () => _showCreateTierDialog(context, ref, l10n, uid),
            ),
          ),
        ],
      ),
    );
  }

  /// 統計カラム
  Widget _buildStatColumn(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
      ],
    );
  }

  /// スポンサーカード
  Widget _buildSponsorCard(BuildContext context, SponsorshipRecord sponsor) {
    final startDate = sponsor.startDate.toString().split(' ')[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: AppColors.shuLight, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sponsor.sponsorDisplayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.washi,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sponsor.tierName} • $startDate',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.kin,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '\$${(sponsor.amountUSD / 100).toStringAsFixed(2)}/月',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.sumi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (sponsor.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '「${sponsor.message}」',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.washiDim,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// 通知カード
  Widget _buildNotificationCard(
    BuildContext context,
    AppLocalizations l10n,
    SponsorshipNotification notif,
  ) {
    final typeText = notif.type == 'new_sponsor' ? l10n.newSponsorLabel :
                     notif.type == 'tier_upgrade' ? l10n.tierUpgradeLabel :
                     l10n.renewalLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications,
            color: AppColors.kin,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$typeText - ${notif.sponsorName}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${(notif.amountUSD / 100).toStringAsFixed(2)} • ${notif.tier}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  void _showCreateTierDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
  ) {
    _logger.i('Creating a sponsorship tier');
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.newTierDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: l10n.tierNameHint),
                style: const TextStyle(color: AppColors.washi),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: l10n.monthlyPriceUsdHint),
                style: const TextStyle(color: AppColors.washi),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(hintText: l10n.descriptionHint),
                style: const TextStyle(color: AppColors.washi),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final priceInputUSD = double.tryParse(priceController.text.trim());
              if (name.isEmpty || priceInputUSD == null || priceInputUSD <= 0) {
                return;
              }
              // amountUSD/priceUSD are stored in cents everywhere else in this
              // feature (see the "/ 100" divisions when displaying them).
              final priceUSD = (priceInputUSD * 100).round();
              Navigator.pop(dialogContext);
              final result = await ref.read(createSponsorshipTierProvider)(
                userId: uid,
                name: name,
                priceUSD: priceUSD,
                description: descriptionController.text.trim(),
                benefits: const [],
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result != null ? l10n.tierCreatedMessage : l10n.genericErrorMessage)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.kin),
            child: Text(l10n.createButton),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      priceController.dispose();
      descriptionController.dispose();
    });
  }
}

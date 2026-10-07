import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 棋風の相性画面 - 自分の棋風プロファイルと、フレンドとの相性を表示
class PlaystyleScreen extends ConsumerWidget {
  const PlaystyleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.playstyleCardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
        actions: uid == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.reanalyzeTooltip,
                  onPressed: () => _recompute(context, l10n, ref, uid),
                ),
              ],
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMyProfile(l10n, ref, uid),
                  const SizedBox(height: 28),
                  Text(
                    l10n.compatibilityWithFriendsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildCompatibilityList(l10n, ref, uid),
                ],
              ),
            ),
    );
  }

  Widget _buildMyProfile(AppLocalizations l10n, WidgetRef ref, String uid) {
    final profileAsync = ref.watch(playstyleProfileProvider(uid));
    return profileAsync.when(
      data: (profile) {
        if (profile.gamesAnalyzed == 0) {
          return _infoBox(l10n.noGamesAnalyzedMessage);
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.aiLight),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.aiLight.withOpacity(0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.myPlaystyleLabel(profile.gamesAnalyzed),
                style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildBar(l10n.aggressivenessLabel, profile.aggressiveness, Colors.redAccent),
              const SizedBox(height: 8),
              _buildBar(l10n.territorialityLabel, profile.territoriality, Colors.blueAccent),
              const SizedBox(height: 8),
              _buildBar(l10n.sacrificeRateLabel, profile.sacrificeRate, Colors.orangeAccent),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Playstyle profile error: $err');
        return Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent));
      },
    );
  }

  Widget _buildBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.sumiCard,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityList(AppLocalizations l10n, WidgetRef ref, String uid) {
    final friendsAsync = ref.watch(friendsStreamProvider(uid));
    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return _infoBox(l10n.addFriendsForCompatibilityMessage);
        }
        final compatAsync = ref.watch(compatibleFriendsProvider(uid));
        return compatAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return _infoBox(l10n.noCompatibilityDataMessage);
            }
            return Column(
              children: results.map((c) {
                final isComplementary = c.compatibilityType == 'complementary';
                return Card(
                  color: AppColors.sumiSurface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      isComplementary ? Icons.compare_arrows : Icons.favorite,
                      color: isComplementary ? Colors.orangeAccent : Colors.pinkAccent,
                    ),
                    title: Text(c.otherDisplayName, style: const TextStyle(color: AppColors.washi)),
                    subtitle: Text(
                      isComplementary ? l10n.complementaryStyleLabel : l10n.similarStyleLabel,
                      style: TextStyle(color: AppColors.washiDim),
                    ),
                    trailing: Text(
                      '${(c.compatibilityScore * 100).round()}%',
                      style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) {
            _logger.e('Compatibility error: $err');
            return Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent));
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Friends list error: $err');
        return Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent));
      },
    );
  }

  Widget _infoBox(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: AppColors.washiDim)),
    );
  }

  Future<void> _recompute(BuildContext context, AppLocalizations l10n, WidgetRef ref, String uid) async {
    try {
      await ref.read(computePlaystyleProfileProvider)(uid);
      ref.invalidate(playstyleProfileProvider(uid));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playstyleReanalyzedMessage)),
        );
      }
    } catch (e) {
      _logger.e('Error recomputing playstyle: $e');
    }
  }
}

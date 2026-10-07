import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'matching_screen.dart';
import 'playstyle_screen.dart';
import 'position_echo_screen.dart';
import 'live_friends_screen.dart';
import 'fateful_moves_screen.dart';
import 'concurrent_players_screen.dart';
import 'en_score_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 縁ハブ画面 - 「碁縁」らしいつながり機能への入り口
class EnHubScreen extends ConsumerWidget {
  const EnHubScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.homeEnHubTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.loginToSeeEnMessage,
                style: const TextStyle(color: AppColors.washiDim),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.enHubIntroTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.enHubIntroSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _buildCard(
                    context,
                    icon: Icons.favorite,
                    color: Colors.pink[300]!,
                    title: l10n.enScoreCardTitle,
                    subtitle: l10n.enScoreCardSubtitle,
                    onTap: () => _push(context, const EnScoreScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.handshake,
                    color: AppColors.kin,
                    title: l10n.matchingTitle,
                    subtitle: l10n.skillMatchingCardSubtitle,
                    onTap: () => _push(context, const MatchingScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.psychology,
                    color: AppColors.aiLight,
                    title: l10n.playstyleCardTitle,
                    subtitle: l10n.playstyleCardSubtitle,
                    onTap: () => _push(context, const PlaystyleScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.history_edu,
                    color: Colors.deepPurple[300]!,
                    title: l10n.positionEchoCardTitle,
                    subtitle: l10n.positionEchoCardSubtitle,
                    onTap: () => _push(context, const PositionEchoScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.live_tv,
                    color: AppColors.shuLight,
                    title: l10n.liveFriendsCardTitle,
                    subtitle: l10n.liveFriendsCardSubtitle,
                    onTap: () => _push(context, const LiveFriendsScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.auto_awesome,
                    color: Colors.orange[400]!,
                    title: l10n.fatefulMovesCardTitle,
                    subtitle: l10n.fatefulMovesCardSubtitle,
                    onTap: () => _push(context, const FatefulMovesScreen()),
                  ),
                  _buildCard(
                    context,
                    icon: Icons.groups,
                    color: AppColors.wakatake,
                    title: l10n.concurrentPlayersCardTitle,
                    subtitle: l10n.concurrentPlayersCardSubtitle,
                    onTap: () => _push(context, const ConcurrentPlayersScreen()),
                  ),
                ],
              ),
            ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    _logger.i('Navigating to ${screen.runtimeType}');
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.6)),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.washi.withOpacity(0.04),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppColors.washiDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

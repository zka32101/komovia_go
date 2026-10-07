import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/shoji_transition.dart';
import 'package:komovia_go/views/widgets/ad_banner.dart';
import 'package:komovia_go/views/widgets/ai_level_sheet.dart';
import 'ai_game_screen.dart';
import 'game_mode_selector_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// HomeScreen - Main hub for all Go learning activities
///
/// Provides access to:
/// - Play AI Game (main path to Aha moment)
/// - Daily Tsume-Go puzzle
/// - Watch kifu library (observation)
/// - Game history
/// - Settings
class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building HomeScreen');

    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final isSubscriptionActive = ref.watch(isSubscriptionActiveProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        // The title lives in flexibleSpace so it is centred on the screen
        // regardless of how many action icons sit on the right.
        title: const SizedBox.shrink(),
        flexibleSpace: SafeArea(
          child: Center(
            child: Text(
              '碁縁',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ),
        backgroundColor: AppColors.sumi,
        elevation: 0,
        actions: [
          _buildMessagesButton(context, ref, l10n, currentUser?.uid),
          _buildNotificationButton(context, ref, l10n, currentUser?.uid),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
            tooltip: l10n.settingsTitle,
            // Default IconButton constraints render a 40x40 tap target,
            // short of WCAG's 44x44dp minimum.
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User greeting & subscription status
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeGreeting,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentUser?.displayName ?? l10n.homeDefaultPlayerName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSubscriptionActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.kin,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.homePremiumBadge,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.sumi,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Main action cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Game Mode Selection - Primary CTA (Phase 58)
                  _buildActionCard(
                    context,
                    title: l10n.homeGameModesTitle,
                    subtitle: l10n.homeGameModesSubtitle,
                    icon: Icons.sports_esports,
                    color: AppColors.kin,
                    onTap: () => _navigateToGameModeSelector(context),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 16),

                  // Classic AI Game option
                  _buildActionCard(
                    context,
                    title: l10n.homePlayAiGameTitle,
                    subtitle: l10n.homePlayAiGameSubtitle,
                    icon: Icons.smart_toy,
                    color: AppColors.kin,
                    onTap: () => _navigateToAiGame(context, ref),
                  ),
                  const SizedBox(height: 16),

                  // Daily Tsume-Go puzzle
                  _buildActionCard(
                    context,
                    title: l10n.homeTodaysPuzzleTitle,
                    subtitle: l10n.homeTodaysPuzzleSubtitle,
                    icon: Icons.lightbulb,
                    color: AppColors.aiLight,
                    onTap: () => _navigateToTsumeGo(context),
                  ),
                  const SizedBox(height: 16),

                  // Watch Kifu
                  _buildActionCard(
                    context,
                    title: l10n.homeWatchLearnTitle,
                    subtitle: l10n.homeWatchLearnSubtitle,
                    icon: Icons.visibility,
                    color: AppColors.wakatake,
                    onTap: () => _navigateToKifuObservation(context),
                  ),
                  const SizedBox(height: 16),

                  // Game History
                  _buildActionCard(
                    context,
                    title: l10n.homeMyGamesTitle,
                    subtitle: l10n.homeMyGamesSubtitle,
                    icon: Icons.history,
                    color: AppColors.fuji,
                    onTap: () => _navigateToGameHistory(context),
                  ),
                  const SizedBox(height: 16),

                  // Friends (add / requests / list)
                  _buildActionCard(
                    context,
                    title: l10n.homeFriendsTitle,
                    subtitle: l10n.homeFriendsSubtitle,
                    icon: Icons.group_add,
                    color: Colors.lightBlue[300]!,
                    onTap: () => Navigator.of(context).pushNamed('/friends'),
                  ),
                  const SizedBox(height: 16),

                  // 縁 (En) hub
                  _buildActionCard(
                    context,
                    title: l10n.homeEnHubTitle,
                    subtitle: l10n.homeEnHubSubtitle,
                    icon: Icons.favorite,
                    color: Colors.pink[300]!,
                    onTap: () => _navigateToEnHub(context),
                  ),
                  const SizedBox(height: 16),

                  // Tournament
                  _buildActionCard(
                    context,
                    title: l10n.homeTournamentTitle,
                    subtitle: l10n.homeTournamentSubtitle,
                    icon: Icons.emoji_events,
                    color: AppColors.kin,
                    onTap: () => _navigateToTournament(context),
                  ),
                  const SizedBox(height: 16),

                  // Active PvP games (マッチング/トーナメント経由で始めた対局に戻る)
                  _buildActionCard(
                    context,
                    title: l10n.homePvpGamesTitle,
                    subtitle: l10n.homePvpGamesSubtitle,
                    icon: Icons.people_alt,
                    color: AppColors.shuLight,
                    onTap: () => _navigateToPvpGames(context),
                  ),
                  const SizedBox(height: 16),

                  // How to Play (persistent reference, unlike onboarding)
                  _buildActionCard(
                    context,
                    title: l10n.homeHowToPlayTitle,
                    subtitle: l10n.homeHowToPlaySubtitle,
                    icon: Icons.menu_book,
                    color: Colors.teal[300]!,
                    onTap: () => _navigateToHowToPlay(context),
                  ),
                  const SizedBox(height: 16),

                  // Joseki (strategy) library
                  _buildActionCard(
                    context,
                    title: l10n.homeJosekiTitle,
                    subtitle: l10n.homeJosekiSubtitle,
                    icon: Icons.auto_stories,
                    color: Colors.indigo[300]!,
                    onTap: () => _navigateToJoseki(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Game count stats
            if (currentUser != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStatsSection(context, l10n, currentUser),
              ),

            const SizedBox(height: 32),

            // Paywall teaser (for free users after 2 games)
            if (!isSubscriptionActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPaywallTeaser(context, l10n, ref),
              ),

            const SizedBox(height: 32),

            // Settings Reset Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSettingsResetButton(context, l10n, ref),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Action card widget
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: color,
            width: isPrimary ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isPrimary
              ? color.withOpacity(0.15)
              : AppColors.washi.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Stats section showing game counts
  Widget _buildStatsSection(BuildContext context, AppLocalizations l10n, User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(
              context,
              label: l10n.statsGamesPlayedLabel,
              value: '${user.gamesPlayedCount}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.sumiLine,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              label: l10n.statsMemberSinceLabel,
              value: _formatDate(user.createdAt),
            ),
          ),
        ],
      ),
    );
  }

  /// Single stat item
  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.kin,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
      ],
    );
  }

  /// Settings reset button
  Widget _buildSettingsResetButton(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.shuLight, width: 1),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.shuDark.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.refresh,
                color: AppColors.shuLight,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.gameSettingsSectionTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.resetSettingsDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.shuLight,
                // vertical: 10 rendered a ~40dp-tall touch target, short of
                // WCAG's 44dp minimum.
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showResetConfirmationDialog(context, l10n, ref),
              child: Text(
                l10n.resetSettingsButton,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Paywall teaser for free users
  Widget _buildPaywallTeaser(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.kin, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.kin.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: AppColors.kin,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.unlockPremiumTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.unlockPremiumDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kin,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _navigateToPaywall(context, ref),
              child: Text(
                l10n.upgradeNowButton,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.sumi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToGameModeSelector(BuildContext context) {
    _logger.i('Navigating to Game Mode Selector');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GameModeSelectorScreen(),
      ),
    );
  }

  Future<void> _navigateToAiGame(BuildContext context, WidgetRef ref) async {
    _logger.i('Navigating to AI Game');
    ref.read(logPaywallTriggeredProvider)(gameNumber: 1);
    // 対局の前にAIの強さを選ばせる（高レベルはプレミアム）。
    final picked = await showAiLevelSheet(context, ref);
    if (!picked || !context.mounted) return;
    // gameBoardStateProvider etc. are plain globals that outlive this
    // screen; without resetting them here, a previous game's finished
    // board would still be showing (see startNewGameProvider's doc).
    ref.read(startNewGameProvider)();
    // 障子が開いて対局へ入るような節目の演出にするため、通常の
    // pushNamedではなくカスタムトランジションで直接pushする。
    Navigator.of(context).push(shojiTransitionRoute(const AIGameScreen()));
  }

  void _navigateToTsumeGo(BuildContext context) {
    _logger.i('Navigating to Tsume-Go');
    Navigator.of(context).pushNamed('/tsume-go');
  }

  void _navigateToKifuObservation(BuildContext context) {
    _logger.i('Navigating to Kifu Observation');
    Navigator.of(context).pushNamed('/kifu-observation');
  }

  void _navigateToGameHistory(BuildContext context) {
    _logger.i('Navigating to Game History');
    Navigator.of(context).pushNamed('/game-history');
  }

  void _navigateToEnHub(BuildContext context) {
    _logger.i('Navigating to En Hub');
    Navigator.of(context).pushNamed('/en-hub');
  }

  void _navigateToTournament(BuildContext context) {
    _logger.i('Navigating to Tournament');
    Navigator.of(context).pushNamed('/tournament');
  }

  void _navigateToPvpGames(BuildContext context) {
    _logger.i('Navigating to active PvP games');
    Navigator.of(context).pushNamed('/pvp-games');
  }

  void _navigateToNotifications(BuildContext context) {
    _logger.i('Navigating to Notifications');
    Navigator.of(context).pushNamed('/notifications');
  }

  void _navigateToHowToPlay(BuildContext context) {
    _logger.i('Navigating to How to Play');
    Navigator.of(context).pushNamed('/how-to-play');
  }

  void _navigateToJoseki(BuildContext context) {
    _logger.i('Navigating to Joseki');
    Navigator.of(context).pushNamed('/joseki');
  }

  /// Messages icon with an unread-count badge
  Widget _buildMessagesButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String? uid,
  ) {
    const minTapTarget = BoxConstraints(minWidth: 44, minHeight: 44);

    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: () => Navigator.of(context).pushNamed('/messages'),
        tooltip: l10n.messagesTitle,
        constraints: minTapTarget,
      );
    }

    final unreadCount = ref.watch(unreadMessageCountProvider(uid));

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () => Navigator.of(context).pushNamed('/messages'),
          tooltip: l10n.messagesTitle,
          constraints: minTapTarget,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: AppColors.washi, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Notification bell with an unread-count badge
  Widget _buildNotificationButton(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String? uid,
  ) {
    // Default IconButton constraints render a 40x40 tap target, short of
    // WCAG's 44x44dp minimum.
    const minTapTarget = BoxConstraints(minWidth: 44, minHeight: 44);

    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none),
        onPressed: () => _navigateToNotifications(context),
        tooltip: l10n.notificationsTooltip,
        constraints: minTapTarget,
      );
    }

    final unreadCountAsync = ref.watch(unreadNotificationCountProvider(uid));
    final unreadCount = unreadCountAsync.valueOrNull ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => _navigateToNotifications(context),
          tooltip: l10n.notificationsTooltip,
          constraints: minTapTarget,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: AppColors.washi, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToSettings(BuildContext context) {
    _logger.i('Navigating to Settings');
    Navigator.of(context).pushNamed('/settings');
  }

  void _navigateToPaywall(BuildContext context, WidgetRef ref) {
    _logger.i('Navigating to Paywall');
    ref.read(logPaywallTriggeredProvider)(gameNumber: 3);
    Navigator.of(context).pushNamed('/paywall');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Settings reset methods
  void _showResetConfirmationDialog(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    _logger.i('Showing reset confirmation dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.sumiSurface,
          title: Text(
            l10n.resetSettingsDialogTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.washi,
            ),
          ),
          content: Text(
            l10n.resetSettingsDialogContent,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.cancelButton,
                style: TextStyle(color: AppColors.aiLight),
              ),
            ),
            TextButton(
              onPressed: () async {
                _logger.i('Confirming settings reset');
                Navigator.pop(dialogContext);

                // Show loading indicator
                _showResetProgressDialog(context, l10n);

                try {
                  // Reset all settings
                  final result =
                      await ref.read(clearAllSettingsProvider.future);

                  if (context.mounted) {
                    Navigator.pop(context); // Close progress dialog

                    if (result) {
                      _logger.i('Settings reset successfully');
                      _showResetSuccessSnackbar(context, l10n);
                    } else {
                      _logger.e('Settings reset failed');
                      _showResetErrorSnackbar(context, l10n);
                    }
                  }
                } catch (e) {
                  _logger.e('Error resetting settings: $e');
                  if (context.mounted) {
                    Navigator.pop(context); // Close progress dialog
                    _showResetErrorSnackbar(context, l10n);
                  }
                }
              },
              child: Text(
                l10n.resetConfirmButton,
                style: TextStyle(color: AppColors.shuLight),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResetProgressDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.sumiSurface,
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
              ),
              const SizedBox(width: 16),
              Text(
                l10n.resettingProgressMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetSuccessSnackbar(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.wakatake),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.resetSuccessMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.wakatakeDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showResetErrorSnackbar(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: AppColors.shuLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.resetErrorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.shuDark,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

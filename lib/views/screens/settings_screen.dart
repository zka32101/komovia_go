import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/danger_hints_provider.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/views/widgets/ad_banner.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

const _prefShareStatistics = 'privacy_share_statistics';
const _prefAnonymousMode = 'privacy_anonymous_mode';

/// SettingsScreen - User preferences and account management
///
/// Features:
/// - Display and edit user profile (name, email)
/// - Board size preference (7x7, 9x9, 13x13, 19x19)
/// - AI difficulty preference slider
/// - Subscription status and upgrade option
/// - Privacy and data settings
/// - Account management (sign out, delete account)
/// - App information and credits
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _displayNameController;
  int _selectedBoardSize = 9;
  int _selectedAiLevel = 5;
  bool _shareStatistics = true;
  bool _anonymousMode = false;

  @override
  void initState() {
    super.initState();
    _logger.i('SettingsScreen initialized');
    _displayNameController = TextEditingController();

    // Initialize board size and AI level from game settings
    Future.microtask(() {
      final blitzSize = ref.read(blitzBoardSizeProvider);
      final blitzLevel = ref.read(blitzAiLevelProvider);
      if (mounted) {
        setState(() {
          _selectedBoardSize = int.tryParse(blitzSize) ?? 9;
          _selectedAiLevel = blitzLevel;
        });
      }
    });

    _loadPrivacyPreferences();
  }

  Future<void> _loadPrivacyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _shareStatistics = prefs.getBool(_prefShareStatistics) ?? true;
      _anonymousMode = prefs.getBool(_prefAnonymousMode) ?? false;
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final isSubscriptionActive = ref.watch(isSubscriptionActiveProvider);

    if (currentUser == null) {
      return _buildAuthRequiredState(context, l10n);
    }

    // Initialize name controller with current user name
    if (_displayNameController.text.isEmpty && currentUser.displayName != null) {
      _displayNameController.text = currentUser.displayName ?? '';
    }

    return Scaffold(
      backgroundColor: AppColors.sumi,
      bottomNavigationBar: const AdBanner(),
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile section
            _buildSection(
              context,
              l10n.sectionProfile,
              _buildProfileSettings(context, l10n, currentUser),
            ),

            // Subscription section
            _buildSection(
              context,
              l10n.sectionSubscription,
              _buildSubscriptionSettings(context, l10n, isSubscriptionActive),
            ),

            // Preferences section
            _buildSection(
              context,
              l10n.sectionPreferences,
              _buildPreferenceSettings(context, l10n),
            ),

            // Language section
            _buildSection(
              context,
              l10n.sectionLanguage,
              _buildLanguageSettings(context, l10n),
            ),

            // Privacy section
            _buildSection(
              context,
              l10n.sectionPrivacy,
              _buildPrivacySettings(context, l10n),
            ),

            // Account section
            _buildSection(
              context,
              l10n.sectionAccount,
              _buildAccountSettings(context, l10n, ref),
            ),

            // Connections / creator features section
            _buildSection(
              context,
              l10n.sectionConnections,
              _buildConnectionsSettings(context, l10n),
            ),

            // App info section
            _buildSection(
              context,
              l10n.sectionAbout,
              _buildAppInfo(context, l10n),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSettings(BuildContext context, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(l10n.languageJapanese),
          selected: currentLocale.languageCode == 'ja',
          onSelected: (_) =>
              ref.read(localeProvider.notifier).setLocale(const Locale('ja')),
          selectedColor: AppColors.kin,
          backgroundColor: AppColors.sumiCard,
        ),
        ChoiceChip(
          label: Text(l10n.languageEnglish),
          selected: currentLocale.languageCode == 'en',
          onSelected: (_) =>
              ref.read(localeProvider.notifier).setLocale(const Locale('en')),
          selectedColor: AppColors.kin,
          backgroundColor: AppColors.sumiCard,
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.kin,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.sumiLine),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.washi.withOpacity(0.03),
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSettings(BuildContext context, AppLocalizations l10n, User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.displayNameLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _displayNameController,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.washi,
          ),
          decoration: InputDecoration(
            hintText: l10n.displayNameHint,
            hintStyle: TextStyle(color: AppColors.grey500),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.sumiLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.kin),
            ),
          ),
          onChanged: (value) {
            _logger.i('Display name changed: $value');
          },
        ),
        const SizedBox(height: 16),
        if (!user.email.endsWith('@goen.local')) ...[
        Text(
          l10n.emailLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.sumiLine),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleShareProfile(context, l10n, user),
            child: Text(l10n.shareProfileButton),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _handleSaveProfile(context, l10n),
            child: Text(l10n.saveChangesButton),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSettings(BuildContext context, AppLocalizations l10n, bool isActive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premiumSubscriptionTitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? l10n.statusActive : l10n.statusInactive,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isActive ? AppColors.wakatake : AppColors.washiDim,
                  ),
                ),
              ],
            ),
            if (!isActive)
              Icon(
                Icons.lock,
                color: AppColors.kin,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isActive ? l10n.premiumActiveDescription : l10n.premiumInactiveDescription,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 16),
        if (!isActive)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleUpgrade(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kin,
              ),
              child: Text(
                l10n.upgradeButton,
                style: TextStyle(
                  color: AppColors.sumi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreferenceSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.preferredBoardSizeLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 8.0;
          final w = (constraints.maxWidth - gap * 3) / 4;
          return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [7, 9, 13, 19].map((size) {
            return SizedBox(width: w, child: ChoiceChip(
              showCheckmark: false,
              label: SizedBox(width: double.infinity, child: Text('${size}×$size', textAlign: TextAlign.center)),
              selected: _selectedBoardSize == size,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedBoardSize = size);
                  ref.read(blitzBoardSizeProvider.notifier).state = size.toString();
                  _logger.i('Board size preference changed to $size');
                }
              },
            ));
          }).toList(),
        );
        }),
        const SizedBox(height: 24),
        Text(
          l10n.defaultAiDifficultyLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: _selectedAiLevel.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: l10n.levelLabel(_selectedAiLevel),
              activeColor: AppColors.kin,
              onChanged: (value) {
                setState(() => _selectedAiLevel = value.toInt());
                ref.read(blitzAiLevelProvider.notifier).state = value.toInt();
                _logger.i('AI difficulty preference changed to $value');
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.beginnerLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  Text(
                    l10n.levelLabel(_selectedAiLevel),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.kin,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.expertLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingSwitch(
          context,
          l10n.dangerHintsTitle,
          l10n.dangerHintsSubtitle,
          ref.watch(dangerHintsProvider),
          (value) => ref.read(dangerHintsProvider.notifier).set(value),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingSwitch(
          context,
          l10n.shareStatsTitle,
          l10n.shareStatsSubtitle,
          _shareStatistics,
          (value) async {
            setState(() => _shareStatistics = value);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefShareStatistics, value);
            _logger.i('Statistics sharing: $value');
          },
        ),
        const SizedBox(height: 16),
        _buildSettingSwitch(
          context,
          l10n.anonymousModeTitle,
          l10n.anonymousModeSubtitle,
          _anonymousMode,
          (value) async {
            setState(() => _anonymousMode = value);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_prefAnonymousMode, value);
            _logger.i('Anonymous mode: $value');
          },
        ),
        const SizedBox(height: 16),
        Text(
          l10n.dataPrivacyLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.privacyDescription,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _handleOpenPrivacyPolicy(context),
          child: Text(l10n.readPrivacyPolicyButton),
        ),
      ],
    );
  }

  Widget _buildSettingSwitch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washi,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.kin,
        ),
      ],
    );
  }

  Widget _buildAccountSettings(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleSignOut(context, l10n, ref),
            child: Text(l10n.signOutButton),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _handleDeleteAccount(context, l10n, ref),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.shuLight),
            ),
            child: Text(
              l10n.deleteAccountButton,
              style: TextStyle(color: AppColors.shuLight),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.deleteAccountDescription,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.shuLight,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionsSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnectionRow(
          context,
          icon: Icons.favorite,
          label: l10n.sponsorshipLabel,
          onTap: () => Navigator.of(context).pushNamed('/sponsorship'),
        ),
        const Divider(color: AppColors.sumiLine, height: 24),
        _buildConnectionRow(
          context,
          icon: Icons.live_tv,
          label: l10n.twitchStreamLabel,
          onTap: () => Navigator.of(context).pushNamed('/twitch-stream'),
        ),
        const Divider(color: AppColors.sumiLine, height: 24),
        _buildConnectionRow(
          context,
          icon: Icons.video_library,
          label: l10n.youtubeShareLabel,
          onTap: () => Navigator.of(context).pushNamed('/youtube-share'),
        ),
      ],
    );
  }

  Widget _buildConnectionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.kin, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.washi),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey500),
        ],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(context, l10n.appNameFieldLabel, 'GoEn - 碁縁'),
        const SizedBox(height: 12),
        _buildInfoRow(context, l10n.versionFieldLabel, '1.0.0'),
        const SizedBox(height: 12),
        _buildInfoRow(context, l10n.buildFieldLabel, '2026.09.01'),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => _handleOpenTerms(context),
          child: Text(l10n.termsOfServiceButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _handleOpenPrivacyPolicy(context),
          child: Text(l10n.privacyPolicyButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _handleOpenCredits(context, l10n),
          child: Text(l10n.creditsButton),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washi,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthRequiredState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 64,
            color: AppColors.kin,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loginRequiredTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.goBackButton),
          ),
        ],
      ),
    );
  }

  void _handleSaveProfile(BuildContext context, AppLocalizations l10n) async {
    _logger.i('Saving profile changes');

    if (_displayNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.displayNameEmptyError)),
      );
      return;
    }

    try {
      await ref.read(updateDisplayNameProvider(_displayNameController.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdatedMessage)),
        );
      }
    } catch (e) {
      _logger.e('Failed to save profile: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdateFailedMessage('$e'))),
        );
      }
    }
  }

  Future<void> _handleShareProfile(BuildContext context, AppLocalizations l10n, User user) async {
    _logger.i('Opening share dialog for user profile');

    // 対局/パズルの実績はレーティング用・パズル用で別々のリーダーボード
    // ドキュメントに分かれて保存されているため、それぞれ個別に取得する。
    // どれか失敗しても共有自体は止めず、0のままフォールバックする。
    var winCount = 0;
    var totalPuzzlesSolved = 0;
    var currentPuzzleStreak = 0;
    try {
      final ratingEntry = await ref.read(userLeaderboardRankProvider(
        (uid: user.uid, period: LeaderboardPeriod.allTime, type: LeaderboardType.rating),
      ).future);
      winCount = ratingEntry?.wins ?? 0;

      final puzzleEntry = await ref.read(userLeaderboardRankProvider(
        (uid: user.uid, period: LeaderboardPeriod.allTime, type: LeaderboardType.puzzles),
      ).future);
      totalPuzzlesSolved = puzzleEntry?.puzzlesSolved ?? 0;

      currentPuzzleStreak = await ref.read(tsumeGoStreakProvider(user.uid).future);
    } catch (e) {
      _logger.e('Failed to fetch profile stats for sharing: $e');
    }

    if (!context.mounted) return;

    final profileShareData = ProfileShareData(
      userId: user.uid,
      displayName: user.displayName ?? 'GoEn Player',
      totalGamesPlayed: user.gamesPlayedCount,
      winCount: winCount,
      currentPuzzleStreak: currentPuzzleStreak,
      totalPuzzlesSolved: totalPuzzlesSolved,
    );

    final profileContent = _generateProfileShareContent(profileShareData);

    showModalBottomSheet(
      context: context,
      builder: (_) => ShareDialog(
        content: profileContent,
        onShare: (platform) async {
          _logger.i('Sharing profile via $platform');
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileSharedMessage('$platform'))),
          );
        },
      ),
    );
  }

  ShareContent _generateProfileShareContent(ProfileShareData data) {
    final winRate = data.totalGamesPlayed > 0
        ? ((data.winCount / data.totalGamesPlayed) * 100).toStringAsFixed(1)
        : '0.0';

    final text = '''🎓 碁縁でのプログレス報告

👤 ${data.displayName}
🎮 対局数: ${data.totalGamesPlayed}
🏆 勝利数: ${data.winCount} (勝率: $winRate%)
💯 詰碁: ${data.totalPuzzlesSolved}問
🔥 連続成功: ${data.currentPuzzleStreak}問

AI解説で碁を上達しよう！''';

    return ShareContent(
      text: text,
      hashtags: '#碁 #碁縁 #Go学習 #AI解説',
    );
  }

  void _handleUpgrade(BuildContext context) {
    _logger.i('Opening paywall for upgrade');
    Navigator.of(context).pushNamed('/paywall');
  }

  void _handleSignOut(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.signOutDialogTitle),
        content: Text(l10n.signOutDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _logger.i('User signed out');
              try {
                await ref.read(signOutProvider)();
              } catch (e) {
                _logger.e('Sign out error: $e');
              }
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/splash',
                  (route) => false,
                );
              }
            },
            child: Text(l10n.signOutButton),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context, AppLocalizations l10n, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.deleteAccountDialogTitle),
        content: Text(l10n.deleteAccountDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _logger.w('User deleted account');
              try {
                await ref.read(deleteAccountProvider)();
              } catch (e) {
                _logger.e('Delete account error: $e');
              }
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/splash',
                  (route) => false,
                );
              }
            },
            child: Text(
              l10n.deleteButton,
              style: TextStyle(color: AppColors.shuLight),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOpenTerms(BuildContext context) {
    _logger.i('Opening terms of service');
    Navigator.of(context).pushNamed('/terms-of-service');
  }

  void _handleOpenPrivacyPolicy(BuildContext context) {
    _logger.i('Opening privacy policy');
    Navigator.of(context).pushNamed('/privacy-policy');
  }

  void _handleOpenCredits(BuildContext context, AppLocalizations l10n) {
    _logger.i('Opening credits');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.creditsDialogTitle),
        content: SingleChildScrollView(
          child: Text(l10n.creditsDialogContent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }
}

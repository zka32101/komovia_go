import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// PuzzleRushSettingsScreen
class PuzzleRushSettingsScreen extends ConsumerStatefulWidget {
  const PuzzleRushSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PuzzleRushSettingsScreen> createState() =>
      _PuzzleRushSettingsScreenState();
}

class _PuzzleRushSettingsScreenState extends ConsumerState<PuzzleRushSettingsScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreviousSettings();
  }

  Future<void> _loadPreviousSettings() async {
    try {
      _logger.i('Loading previous Puzzle Rush settings...');
      await ref.read(loadPuzzleRushSettingsProvider.future);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _logger.i('Puzzle Rush settings loaded successfully');
    } catch (e) {
      _logger.w('Failed to load previous settings: $e, using defaults');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = AppLocalizations.of(context)!.settingsLoadFallbackMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building PuzzleRushSettingsScreen');
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return _buildLoadingScreen(context, l10n);
    }

    final difficulty = ref.watch(puzzleRushDifficultyProvider);
    final isValid = ref.watch(isPuzzleRushSettingsValidProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.puzzleRushSettingsTitle),
        backgroundColor: AppColors.sumi,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadError != null) _buildErrorMessage(context),

            _buildSectionTitle(context, l10n.selectDifficultyLabel),
            const SizedBox(height: 16),
            _buildDifficultyCards(l10n, ref, difficulty),
            const SizedBox(height: 32),

            _buildSessionInfo(context, l10n),
            const SizedBox(height: 32),

            _buildStartButton(context, l10n, ref, isValid),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.puzzleRushSettingsTitle),
        backgroundColor: AppColors.sumi,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.loadingSettingsMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.washi,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[600]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.orange[300], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _loadError!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.orange[100],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.washi,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDifficultyCards(AppLocalizations l10n, WidgetRef ref, String selected) {
    final difficulties = [
      {'label': l10n.difficultyEasy, 'value': 'easy', 'color': AppColors.wakatake},
      {'label': l10n.difficultyMedium, 'value': 'normal', 'color': Colors.yellow[700]},
      {'label': l10n.difficultyHard, 'value': 'hard', 'color': Colors.orange[700]},
      {'label': l10n.difficultyExpertLabel, 'value': 'expert', 'color': AppColors.shuLight},
    ];

    return Column(
      children: difficulties.map((diff) {
        final isSelected = selected == diff['value'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              ref.read(puzzleRushDifficultyProvider.notifier).state =
                  diff['value'] as String;
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (diff['color'] as Color?)?.withAlpha(100)
                    : AppColors.sumiSurface,
                border: Border.all(
                  color: isSelected
                      ? (diff['color'] as Color?)!
                      : AppColors.washiDim,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    diff['label'] as String,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isSelected ? AppColors.washi : AppColors.washiDim,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: diff['color'] as Color?),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSessionInfo(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sumiSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionInfoTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.timer, color: AppColors.kin, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.fiveMinuteSessionLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.whatshot, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.comboSystemLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.leaderboard, color: AppColors.kin, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.globalLeaderboardLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, AppLocalizations l10n, WidgetRef ref, bool isValid) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid ? AppColors.kin : AppColors.washiDim,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: isValid
            ? () async {
                final settings = ref.watch(puzzleRushSettingsProvider);
                _logger.i('Starting Puzzle Rush: $settings');

                // Save settings to persistent storage
                await ref.read(savePuzzleRushSettingsProvider(settings).future);

                // Navigate to game screen
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/puzzle-rush',
                    (route) => route.settings.name == '/home',
                    arguments: {'settings': settings},
                  );
                }
              }
            : null,
        child: Text(
          l10n.startGameButton,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

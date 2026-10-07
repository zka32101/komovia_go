import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/views/widgets/ai_level_sheet.dart';

final _logger = Logger();

/// GameModeSelectorScreen - Choose your game mode
///
/// Displays available game modes:
/// - Blitz (5分高速対局)
/// - Correspondence (ターンベース)
/// - Team Play (2vs2チーム戦)
/// - Puzzle Rush (詰碁タイムアタック)
///
/// Selection navigates to the appropriate game screen with settings
class GameModeSelectorScreen extends ConsumerWidget {
  const GameModeSelectorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building GameModeSelectorScreen');
    final l10n = AppLocalizations.of(context)!;

    final gameModes = ref.watch(activeGameModesProvider);
    final selectedMode = ref.watch(selectedGameModeProvider);
    final uiState = ref.watch(gameModeUIProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.gameModeSelectorTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: gameModes.when(
        data: (modes) {
          if (modes.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return _buildModesList(context, ref, l10n, modes, selectedMode, uiState);
        },
        loading: () => _buildLoadingState(context, l10n),
        error: (error, stackTrace) =>
            _buildErrorState(context, l10n, error.toString()),
      ),
    );
  }

  /// Build the game modes list/grid
  Widget _buildModesList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<GameMode> modes,
    GameMode? selectedMode,
    GameModeUIState uiState,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.selectModeToMatchLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.washiDim,
              ),
            ),
            const SizedBox(height: 16),
            // Display modes as cards in a grid
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.9,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: modes.length,
              itemBuilder: (context, index) {
                final mode = modes[index];
                final isSelected = selectedMode?.id == mode.id;
                return _buildModeCard(
                  context,
                  ref,
                  l10n,
                  mode,
                  isSelected,
                  uiState.isLoading,
                );
              },
            ),
            if (uiState.error != null) ...[
              const SizedBox(height: 16),
              _buildErrorSnackbar(uiState.error!),
            ],
          ],
        ),
      ),
    );
  }

  /// Build individual mode card
  Widget _buildModeCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GameMode mode,
    bool isSelected,
    bool isLoading,
  ) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () => _selectMode(context, ref, mode),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.kin : AppColors.washiDim,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.kin.withAlpha(50) : AppColors.sumiSurface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode icon & name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeIcon(mode.type),
                  const SizedBox(height: 8),
                  Text(
                    mode.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _modeHint(context, mode.type),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Mode details
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeBadge(l10n, mode),
                  const SizedBox(height: 4),
                  if (mode.timeLimit > 0)
                    Text(
                      l10n.timeLimitSecondsLabel(mode.timeLimit),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                  if (mode.maxPlayers > 1)
                    Text(
                      l10n.maxPlayersLabel(mode.maxPlayers),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One-line explanation shown on each mode card.
  String _modeHint(BuildContext context, GameModeType type) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    switch (type) {
      case GameModeType.blitz:
        return ja ? '持ち時間の短い早打ち対局' : 'Fast games on a short clock';
      case GameModeType.correspondence:
        return ja ? '1手ずつ好きな時間に打てる' : 'Play each move at your own pace';
      case GameModeType.team:
        return ja ? 'チームで対戦' : 'Play together as a team';
      case GameModeType.puzzleRush:
        return ja ? '制限時間内に詰碁を解く' : 'Solve puzzles against the clock';
      case GameModeType.handicap:
        return ja ? '先に石を置いて実力差を補う' : 'Even out skill with starting stones';
      case GameModeType.traditional:
        return ja ? '標準ルールの1局' : 'A standard game';
    }
  }

  /// Get icon for game mode type
  Widget _buildModeIcon(GameModeType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case GameModeType.blitz:
        iconData = Icons.bolt;
        color = AppColors.shuLight;
      case GameModeType.correspondence:
        iconData = Icons.schedule;
        color = AppColors.aiLight;
      case GameModeType.team:
        iconData = Icons.group;
        color = AppColors.wakatake;
      case GameModeType.puzzleRush:
        iconData = Icons.quiz;
        color = AppColors.fuji;
      case GameModeType.handicap:
        iconData = Icons.balance;
        color = Colors.orange[400]!;
      case GameModeType.traditional:
        iconData = Icons.grid_on;
        color = AppColors.washiDim;
    }

    return Icon(iconData, color: color, size: 28);
  }

  /// Build difficulty/type badge
  Widget _buildModeBadge(AppLocalizations l10n, GameMode mode) {
    Color badgeColor;
    String difficultyText;

    switch (mode.difficulty) {
      case 'easy':
        badgeColor = AppColors.wakatake;
        difficultyText = l10n.difficultyEasy;
      case 'medium':
        badgeColor = Colors.yellow[700]!;
        difficultyText = l10n.difficultyMedium;
      case 'hard':
        badgeColor = AppColors.shuLight;
        difficultyText = l10n.difficultyHard;
      case 'master':
        badgeColor = AppColors.fuji;
        difficultyText = l10n.difficultyMaster;
      default:
        badgeColor = AppColors.washiDim;
        difficultyText = mode.difficulty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        difficultyText,
        style: const TextStyle(
          color: AppColors.washi,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Handle mode selection and navigation
  void _selectMode(BuildContext context, WidgetRef ref, GameMode mode) {
    _logger.i('Selected game mode: ${mode.name}');

    // Update UI state
    ref.read(gameModeUIProvider.notifier).selectMode(mode);
    ref.read(selectedGameModeProvider.notifier).state = mode;

    // Navigate based on mode type
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!context.mounted) return;

      switch (mode.type) {
        case GameModeType.blitz:
          _navigateToBlitzGame(context, mode);
        case GameModeType.correspondence:
          _navigateToCorrespondenceGame(context, mode);
        case GameModeType.team:
          _navigateToTeamGame(context, mode);
        case GameModeType.puzzleRush:
          _navigateToPuzzleRush(context, mode);
        case GameModeType.handicap:
          Navigator.of(context).pushNamed('/handicap-settings');
        case GameModeType.traditional:
          showAiLevelSheet(context, ref).then((picked) {
            if (picked && context.mounted) {
              Navigator.of(context).pushNamed('/ai-game');
            }
          });
      }
    });
  }

  void _navigateToBlitzGame(BuildContext context, GameMode mode) {
    _logger.i('Navigating to Blitz settings: ${mode.name}');
    Navigator.of(context).pushNamed(
      '/blitz-settings',
      arguments: {'mode': mode},
    );
  }

  void _navigateToCorrespondenceGame(BuildContext context, GameMode mode) {
    _logger.i('Navigating to Correspondence settings: ${mode.name}');
    Navigator.of(context).pushNamed(
      '/correspondence-settings',
      arguments: {'mode': mode},
    );
  }

  void _navigateToTeamGame(BuildContext context, GameMode mode) {
    _logger.i('Navigating to Team settings: ${mode.name}');
    Navigator.of(context).pushNamed(
      '/team-settings',
      arguments: {'mode': mode},
    );
  }

  void _navigateToPuzzleRush(BuildContext context, GameMode mode) {
    _logger.i('Navigating to Puzzle Rush settings: ${mode.name}');
    Navigator.of(context).pushNamed(
      '/puzzle-rush-settings',
      arguments: {'mode': mode},
    );
  }

  // ================== UI BUILDERS ==================

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.kin),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loadingGameModesMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_esports_outlined,
            size: 48,
            color: AppColors.grey500,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noGameModesMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.shuLight,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.genericErrorMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSnackbar(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.shuDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.shuLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: AppColors.washi,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

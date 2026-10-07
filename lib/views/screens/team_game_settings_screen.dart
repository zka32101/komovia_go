import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// TeamGameSettingsScreen
class TeamGameSettingsScreen extends ConsumerStatefulWidget {
  const TeamGameSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TeamGameSettingsScreen> createState() =>
      _TeamGameSettingsScreenState();
}

class _TeamGameSettingsScreenState extends ConsumerState<TeamGameSettingsScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreviousSettings();
  }

  Future<void> _loadPreviousSettings() async {
    try {
      _logger.i('Loading previous Team settings...');
      await ref.read(loadTeamSettingsProvider.future);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _logger.i('Team settings loaded successfully');
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
    _logger.i('Building TeamGameSettingsScreen');
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return _buildLoadingScreen(context, l10n);
    }

    final boardSize = ref.watch(teamBoardSizeProvider);
    final team1 = ref.watch(team1PlayersProvider);
    final team2 = ref.watch(team2PlayersProvider);
    final isValid = ref.watch(isTeamSettingsValidProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.teamSettingsTitle),
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

            _buildSectionTitle(context, l10n.boardSizeLabel),
            const SizedBox(height: 12),
            _buildBoardSizeSelector(ref, boardSize),
            const SizedBox(height: 32),

            _buildSectionTitle(context, l10n.team1Label),
            const SizedBox(height: 12),
            _buildTeamInfo(context, l10n, team1),
            const SizedBox(height: 32),

            _buildSectionTitle(context, l10n.team2Label),
            const SizedBox(height: 12),
            _buildTeamInfo(context, l10n, team2),
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
        title: Text(l10n.teamSettingsTitle),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.washi,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBoardSizeSelector(WidgetRef ref, String selected) {
    return Row(
      children: ['9', '13', '19'].map((size) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selected == size ? AppColors.kin : AppColors.sumiCard,
              ),
              onPressed: () {
                ref.read(teamBoardSizeProvider.notifier).state = size;
              },
              child: Text('${size}×$size',
                  style: TextStyle(
                    color: selected == size ? AppColors.sumi : AppColors.washi,
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeamInfo(BuildContext context, AppLocalizations l10n, List<String> players) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sumiSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.washiDim),
      ),
      child: Column(
        children: [
          Text(
            l10n.playersOfTwoLabel(players.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: players.length == 2 ? AppColors.wakatake : Colors.yellow[600],
            ),
          ),
          const SizedBox(height: 8),
          if (players.isNotEmpty)
            ...players.map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(p,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.washiDim,
                  )),
            )).toList()
          else
            Text(l10n.noPlayersSelectedMessage,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.washiDim,
                )),
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
                final settings = ref.watch(teamGameSettingsProvider);
                _logger.i('Starting Team game: $settings');

                // Save settings to persistent storage
                await ref.read(saveTeamSettingsProvider(settings).future);

                // Navigate to game screen
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/team-game',
                    (route) => route.settings.name == '/home',
                    arguments: {'settings': settings},
                  );
                }
              }
            : null,
        child: Text(l10n.startGameButton),
      ),
    );
  }
}

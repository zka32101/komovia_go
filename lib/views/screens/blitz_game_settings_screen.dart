import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// BlitzGameSettingsScreen - Blitz game settings before starting
class BlitzGameSettingsScreen extends ConsumerStatefulWidget {
  const BlitzGameSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BlitzGameSettingsScreen> createState() =>
      _BlitzGameSettingsScreenState();
}

class _BlitzGameSettingsScreenState
    extends ConsumerState<BlitzGameSettingsScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreviousSettings();
  }

  Future<void> _loadPreviousSettings() async {
    try {
      _logger.i('Loading previous Blitz settings...');
      await ref.read(loadBlitzSettingsProvider.future);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _logger.i('Blitz settings loaded successfully');
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
    _logger.i('Building BlitzGameSettingsScreen');
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return _buildLoadingScreen(context, l10n);
    }

    final boardSize = ref.watch(blitzBoardSizeProvider);
    final aiLevel = ref.watch(blitzAiLevelProvider);
    final isValid = ref.watch(isBlitzSettingsValidProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.blitzSettingsTitle),
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

            // Board Size Selection
            _buildSectionTitle(context, l10n.boardSizeLabel),
            const SizedBox(height: 12),
            _buildBoardSizeSelector(ref, boardSize),
            const SizedBox(height: 32),

            // AI Level Selection
            _buildSectionTitle(context, l10n.aiDifficultyLabel),
            const SizedBox(height: 12),
            _buildAILevelSlider(context, l10n, ref, aiLevel),
            const SizedBox(height: 32),

            // Start Button
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
        title: Text(l10n.blitzSettingsTitle),
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
                ref.read(blitzBoardSizeProvider.notifier).state = size;
              },
              child: Text(
                '${size}×$size',
                style: TextStyle(
                  color: selected == size ? AppColors.sumi : AppColors.washi,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAILevelSlider(
      BuildContext context, AppLocalizations l10n, WidgetRef ref, int level) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: level.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: AppColors.kin,
          onChanged: (value) {
            ref.read(blitzAiLevelProvider.notifier).state = value.toInt();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.beginnerLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.washiDim)),
              Text(l10n.levelLabel(level),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.washi)),
              Text(l10n.expertLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.washiDim)),
            ],
          ),
        ),
      ],
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
                final settings = ref.watch(blitzGameSettingsProvider);
                _logger.i('Starting Blitz game with settings: $settings');

                // Save settings to persistent storage
                await ref.read(saveBlitzSettingsProvider(settings).future);

                // Navigate to Blitz game screen with settings
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/blitz-game',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// CorrespondenceGameSettingsScreen
class CorrespondenceGameSettingsScreen extends ConsumerStatefulWidget {
  const CorrespondenceGameSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CorrespondenceGameSettingsScreen> createState() =>
      _CorrespondenceGameSettingsScreenState();
}

class _CorrespondenceGameSettingsScreenState
    extends ConsumerState<CorrespondenceGameSettingsScreen> {
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreviousSettings();
  }

  Future<void> _loadPreviousSettings() async {
    try {
      _logger.i('Loading previous Correspondence settings...');
      await ref.read(loadCorrespondenceSettingsProvider.future);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _logger.i('Correspondence settings loaded successfully');
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
    _logger.i('Building CorrespondenceGameSettingsScreen');
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return _buildLoadingScreen(context, l10n);
    }

    final boardSize = ref.watch(correspondenceBoardSizeProvider);
    final playerColor = ref.watch(correspondencePlayerColorProvider);
    final isValid = ref.watch(isCorrespondenceSettingsValidProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.correspondenceSettingsTitle),
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

            _buildSectionTitle(context, l10n.playerColorLabel),
            const SizedBox(height: 12),
            _buildColorSelector(l10n, ref, playerColor),
            const SizedBox(height: 32),

            _buildSectionTitle(context, l10n.considerationTimeLabel),
            const SizedBox(height: 12),
            _buildConsiderationTimeInfo(context, l10n),
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
        title: Text(l10n.correspondenceSettingsTitle),
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
                ref.read(correspondenceBoardSizeProvider.notifier).state = size;
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

  Widget _buildColorSelector(AppLocalizations l10n, WidgetRef ref, String selected) {
    return Row(
      children: ['black', 'white', 'random'].map((color) {
        final label = color == 'black' ? l10n.colorBlackLabel : color == 'white' ? l10n.colorWhiteLabel : l10n.randomColorOption;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selected == color ? AppColors.kin : AppColors.sumiCard,
              ),
              onPressed: () {
                ref.read(correspondencePlayerColorProvider.notifier).state =
                    color;
              },
              child: Text(label,
                  style: TextStyle(
                    color: selected == color ? AppColors.sumi : AppColors.washi,
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConsiderationTimeInfo(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sumiSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l10n.considerationTimeInfoMessage,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.washiDim,
        ),
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
                final settings = ref.watch(correspondenceGameSettingsProvider);
                _logger.i('Starting Correspondence game: $settings');

                // Save settings to persistent storage
                await ref.read(
                    saveCorrespondenceSettingsProvider(settings).future);

                // Navigate to game screen
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/correspondence-game',
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// HandicapGameSettingsScreen - choose board size and handicap stone count
/// before starting a handicap game against the AI.
///
/// Handicap stones are pre-placed on the standard star points and the
/// game starts with white (the AI) to move - see
/// game_provider.dart's startNewGameProvider and utils/handicap_points.dart.
class HandicapGameSettingsScreen extends ConsumerStatefulWidget {
  const HandicapGameSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HandicapGameSettingsScreen> createState() =>
      _HandicapGameSettingsScreenState();
}

class _HandicapGameSettingsScreenState
    extends ConsumerState<HandicapGameSettingsScreen> {
  int _boardSize = 19;
  int _handicapStones = 4;

  @override
  Widget build(BuildContext context) {
    _logger.i('Building HandicapGameSettingsScreen');
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.handicapSettingsTitle),
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
            Text(
              l10n.handicapIntroMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.washiDim,
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(context, l10n.boardSizeLabel),
            const SizedBox(height: 12),
            _buildBoardSizeSelector(),
            const SizedBox(height: 32),

            _buildSectionTitle(context, l10n.handicapStonesCountLabel),
            const SizedBox(height: 12),
            _buildHandicapSlider(context, l10n),
            const SizedBox(height: 32),

            _buildStartButton(context, l10n),
          ],
        ),
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

  Widget _buildBoardSizeSelector() {
    return Row(
      children: [9, 13, 19].map((size) {
        final selected = _boardSize == size;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selected ? AppColors.kin : AppColors.sumiCard,
              ),
              onPressed: () => setState(() => _boardSize = size),
              child: Text(
                '$size×$size',
                style: TextStyle(
                  color: selected ? AppColors.sumi : AppColors.washi,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHandicapSlider(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: _handicapStones.toDouble(),
          min: 2,
          max: 9,
          divisions: 7,
          activeColor: AppColors.kin,
          onChanged: (value) => setState(() => _handicapStones = value.toInt()),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(
              l10n.stonesCountShortLabel(_handicapStones),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.washi,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kin,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          _logger.i(
            'Starting handicap game: boardSize=$_boardSize, handicap=$_handicapStones',
          );
          ref.read(startNewGameProvider)(
            boardSize: _boardSize,
            handicapStones: _handicapStones,
          );
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/ai-game',
            (route) => route.settings.name == '/home',
          );
        },
        child: Text(
          l10n.startGameButton,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

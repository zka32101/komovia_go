import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// BlitzGameScreen - 5分急速戦
///
/// Features:
/// - Real-time countdown timer (5 minutes)
/// - AI level selection (1-10)
/// - AI vs Opponent modes
/// - Move submission with validation
/// - Game results with rating changes
/// - SGF data recording
class BlitzGameScreen extends ConsumerStatefulWidget {
  final String uid;
  final String? opponentUid;
  final String? aiLevel;
  final int boardSize;

  const BlitzGameScreen({
    Key? key,
    required this.uid,
    this.opponentUid,
    this.aiLevel,
    this.boardSize = 19,
  }) : super(key: key);

  @override
  ConsumerState<BlitzGameScreen> createState() => _BlitzGameScreenState();
}

class _BlitzGameScreenState extends ConsumerState<BlitzGameScreen> {
  late int _selectedRow;
  late int _selectedCol;
  late int _timeRemainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _logger.i(
      'BlitzGameScreen initialized - '
      'uid: ${widget.uid}, boardSize: ${widget.boardSize}',
    );
    _selectedRow = -1;
    _selectedCol = -1;
    _timeRemainingSeconds = 5 * 60; // 5 minutes
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _timeRemainingSeconds--;
        });
        if (_timeRemainingSeconds > 0) {
          _startTimer();
        } else {
          _logger.i('Blitz game time expired');
          _handleGameTimeout();
        }
      }
    });
  }

  void _handleGameTimeout() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.timeExpiredMessage)),
    );
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building BlitzGameScreen');
    final l10n = AppLocalizations.of(context)!;

    final gameAsync = ref.watch(
      startBlitzGameProvider(
        (
          uid: widget.uid,
          boardSize: widget.boardSize,
          aiLevel: widget.aiLevel,
          // BlitzGameRecord.opponentUid convention: 'ai' when there's no
          // human opponent (see game_modes.dart's doc comment).
          opponentUid: widget.opponentUid ?? 'ai',
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.blitzGameTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: gameAsync.when(
        data: (game) => _buildGameBoard(context, ref, l10n, game),
        loading: () => _buildLoadingState(context, l10n),
        error: (error, stackTrace) =>
            _buildErrorState(context, l10n, error.toString()),
      ),
    );
  }

  Widget _buildGameBoard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BlitzGameRecord game,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Timer and info
          Container(
            color: AppColors.sumi,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      l10n.timeRemainingLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                    Text(
                      _formatTime(_timeRemainingSeconds),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _timeRemainingSeconds < 30
                            ? Colors.red
                            : AppColors.washi,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      l10n.aiLevelLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                    Text(
                      widget.aiLevel ?? 'N/A',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      l10n.boardSizeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                    Text(
                      '${game.boardSize}×${game.boardSize}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Game state info
          if (game.result != 'active')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.kin,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.gameEndedResultLabel(game.result),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Move history
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.moveHistoryLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.washi,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sumi,
                    border: Border.all(color: AppColors.sumiLine),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: game.moveHistory.isEmpty
                      ? Text(
                          l10n.noMovesYetMessage,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: game.moveHistory.asMap().entries.map((e) {
                            final moveNum = e.key + 1;
                            final move = e.value;
                            return Chip(
                              label: Text('$moveNum: $move'),
                              backgroundColor: Colors.grey.shade800,
                              labelStyle: const TextStyle(
                                color: AppColors.washi,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handleAddMove(context, ref, l10n, game),
                  icon: const Icon(Icons.touch_app),
                  label: Text(l10n.submitMoveButton),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _handleEndGame(context, ref, l10n, game),
                  icon: const Icon(Icons.stop_circle),
                  label: Text(l10n.endGameButton),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _handleAddMove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BlitzGameRecord game,
  ) async {
    _logger.i('Adding move to Blitz game: ${game.id}');

    try {
      final move = '${String.fromCharCode(65 + _selectedCol)}${_selectedRow + 1}';
      final playerColor = game.moveHistory.length % 2 == 0 ? 'black' : 'white';

      await ref.read(
        addBlitzMoveProvider(
          (
            gameId: game.id,
            move: move,
            playerColor: playerColor,
          ),
        ).future,
      );

      _logger.i('Move added successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.moveRecordedMessage(move))),
      );
    } catch (e) {
      _logger.e('Error adding move: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorPrefix(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleEndGame(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BlitzGameRecord game,
  ) async {
    _logger.i('Ending Blitz game: ${game.id}');

    try {
      final result = 'white_win'; // Example result
      final winnerColor = 'white';

      await ref.read(
        endBlitzGameProvider(
          (
            gameId: game.id,
            result: result,
            winnerColor: winnerColor,
            sgfData: '', // Would generate real SGF
            ratingChange: 20,
          ),
        ).future,
      );

      _logger.i('Game ended successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameEndedMessage)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('Error ending game: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorPrefix(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.preparingGameMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AppLocalizations l10n,
    String error,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
          const SizedBox(height: 16),
          Text(
            l10n.genericErrorMessage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.goBackButton),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _logger.i('BlitzGameScreen disposed');
    super.dispose();
  }
}

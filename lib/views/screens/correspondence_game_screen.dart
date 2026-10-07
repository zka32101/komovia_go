import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// CorrespondenceGameScreen - 手紙型ターン制対局
///
/// Features:
/// - Ongoing games list with status
/// - Turn-by-turn move submission
/// - Current player color indicator
/// - Opponent notification system
/// - Game history with timestamps
/// - Game abandonment option
class CorrespondenceGameScreen extends ConsumerWidget {
  final String uid;
  final String opponentUid;
  final int boardSize;

  const CorrespondenceGameScreen({
    Key? key,
    required this.uid,
    required this.opponentUid,
    this.boardSize = 19,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building CorrespondenceGameScreen');
    final l10n = AppLocalizations.of(context)!;

    final gamesAsync = ref.watch(
      userCorrespondenceGamesProvider(uid),
    );
    final pendingMovesAsync = ref.watch(
      pendingMoveCountProvider(uid),
    );

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.correspondenceGameTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Pending moves badge
            pendingMovesAsync.when(
              data: (count) {
                if (count == 0) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: AppColors.kin,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.washi),
                      const SizedBox(width: 8),
                      Text(
                        l10n.pendingMovesLabel(count),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, _) {
                _logger.e('Error fetching pending moves: $error');
                return const SizedBox.shrink();
              },
            ),

            // Games list
            gamesAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return _buildEmptyState(context, l10n);
                }
                return _buildGamesList(context, ref, l10n, games);
              },
              loading: () => _buildLoadingState(context, l10n),
              error: (error, stackTrace) =>
                  _buildErrorState(context, l10n, error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<CorrespondenceGameRecord> games,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.gamesListLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...games.map((game) => _buildGameCard(context, ref, l10n, game)),
        ],
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CorrespondenceGameRecord game,
  ) {
    final isMyTurn = game.currentPlayerColor == 'black';
    final statusColor = isMyTurn ? Colors.green.shade600 : Colors.orange.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sumi,
        border: Border.all(
          color: statusColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.gameIdLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  Text(
                    game.id.substring(0, 8),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Chip(
                label: Text(
                  game.status == 'active'
                      ? l10n.activeStatusLabel
                      : l10n.completedStatusLabel,
                  style: const TextStyle(color: AppColors.washi, fontSize: 12),
                ),
                backgroundColor: game.status == 'active'
                    ? Colors.blue.shade600
                    : Colors.grey.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.boardSizeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  Text(
                    '${game.boardSize}×${game.boardSize}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.washi,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.turnNumberLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  Text(
                    '${game.currentTurnNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current player
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  game.currentPlayerColor == 'black'
                      ? Icons.circle
                      : Icons.circle_outlined,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMyTurn
                        ? l10n.yourTurnMessage
                        : l10n.waitingOpponentTurnMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Last move info
          if (game.moveHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lastMoveLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                  Text(
                    game.moveHistory.last,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: game.status == 'active' && isMyTurn
                      ? () => _handleAddMove(context, ref, l10n, game)
                      : null,
                  icon: const Icon(Icons.touch_app),
                  label: Text(l10n.moveButtonLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Colors.blue.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: game.status == 'active'
                      ? () => _handleAbandonGame(context, ref, l10n, game)
                      : null,
                  icon: const Icon(Icons.close),
                  label: Text(l10n.abandonButtonLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAddMove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CorrespondenceGameRecord game,
  ) async {
    _logger.i('Adding move to Correspondence game: ${game.id}');

    try {
      const move = 'D4'; // Example move
      final playerColor =
          game.currentPlayerColor == 'black' ? 'white' : 'black';

      await ref.read(
        addCorrespondenceMoveProvider(
          (
            gameId: game.id,
            move: move,
            playerColor: playerColor,
          ),
        ).future,
      );

      _logger.i('Move added successfully');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.moveRecordedMessage(move))),
        );
      }
    } catch (e) {
      _logger.e('Error adding move: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAbandonGame(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    CorrespondenceGameRecord game,
  ) async {
    _logger.i('Abandoning Correspondence game: ${game.id}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sumi,
        title: Text(l10n.abandonConfirmTitle),
        content: Text(l10n.abandonConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.abandonButtonLabel),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(
        abandonCorrespondenceGameProvider(game.id).future,
      );

      _logger.i('Game abandoned successfully');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameAbandonedMessage)),
        );
      }
    } catch (e) {
      _logger.e('Error abandoning game: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorPrefix(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_outline,
            color: AppColors.washiDim,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCorrespondenceGamesMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.add),
            label: Text(l10n.startNewGameButton),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            l10n.loadingGamesListMessage,
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
}

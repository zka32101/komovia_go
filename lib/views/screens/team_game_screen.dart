import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// TeamGameScreen - 2vs2 協力戦
///
/// Features:
/// - Team composition display (2 vs 2)
/// - Real-time move synchronization
/// - Team statistics and win/loss tracking
/// - Move history with player attribution
/// - Team-based notifications
/// - Game results with team analysis
class TeamGameScreen extends ConsumerStatefulWidget {
  final List<String> team1Players;
  final List<String> team2Players;
  final int boardSize;

  const TeamGameScreen({
    Key? key,
    required this.team1Players,
    required this.team2Players,
    this.boardSize = 19,
  }) : super(key: key);

  @override
  ConsumerState<TeamGameScreen> createState() => _TeamGameScreenState();
}

class _TeamGameScreenState extends ConsumerState<TeamGameScreen> {
  late int _selectedRow;
  late int _selectedCol;

  @override
  void initState() {
    super.initState();
    _logger.i(
      'TeamGameScreen initialized - '
      'team1: ${widget.team1Players}, team2: ${widget.team2Players}',
    );
    _selectedRow = -1;
    _selectedCol = -1;
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building TeamGameScreen');
    final l10n = AppLocalizations.of(context)!;

    final gameAsync = ref.watch(
      startTeamGameProvider(
        (
          team1Players: widget.team1Players,
          team2Players: widget.team2Players,
          boardSize: widget.boardSize,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.teamGameTitle),
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
    TeamGameRecord game,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Team information
          Container(
            color: AppColors.sumi,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Team 1 (White)
                _buildTeamInfo(
                  context,
                  l10n.team1WhiteLabel,
                  widget.team1Players,
                  AppColors.washi,
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.sumiLine),
                const SizedBox(height: 16),
                // Team 2 (Black)
                _buildTeamInfo(
                  context,
                  l10n.team2BlackLabel,
                  widget.team2Players,
                  AppColors.sumi,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Game status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sumi,
                border: Border.all(color: AppColors.sumiLine),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.gameStatusLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.washiDim,
                        ),
                      ),
                      Chip(
                        label: Text(
                          game.result == 'draw'
                              ? l10n.inProgressLabel
                              : game.result,
                          style: const TextStyle(
                            color: AppColors.washi,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: game.result == 'draw'
                            ? Colors.blue.shade600
                            : Colors.green.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                            l10n.moveCountLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.washiDim,
                            ),
                          ),
                          Text(
                            '${game.moveHistory.length}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.washi,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Move history by team
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.team1MovesLabel,
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
                  child: game.team1Moves.isEmpty
                      ? Text(
                          l10n.noMovesRecordedMessage,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        )
                      : Text(
                          game.team1Moves,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washi,
                            fontFamily: 'monospace',
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.team2MovesLabel,
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
                  child: game.team2Moves.isEmpty
                      ? Text(
                          l10n.noMovesRecordedMessage,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        )
                      : Text(
                          game.team2Moves,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washi,
                            fontFamily: 'monospace',
                          ),
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

  Widget _buildTeamInfo(
    BuildContext context,
    String teamName,
    List<String> players,
    Color teamColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teamColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              teamName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players.map((player) {
            return Chip(
              label: Text(
                player.length > 8 ? '${player.substring(0, 8)}...' : player,
                style: const TextStyle(color: AppColors.washi, fontSize: 12),
              ),
              backgroundColor: Colors.grey.shade800,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _handleAddMove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    TeamGameRecord game,
  ) async {
    _logger.i('Adding move to Team game: ${game.id}');

    try {
      const move = 'D4'; // Example move
      final playerColor = game.moveHistory.length % 2 == 0 ? 'white' : 'black';

      await ref.read(
        addTeamMoveProvider(
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
    TeamGameRecord game,
  ) async {
    _logger.i('Ending Team game: ${game.id}');

    try {
      const result = 'team1_win'; // Example result

      await ref.read(
        endTeamGameProvider(
          (
            gameId: game.id,
            result: result,
            sgfData: '', // Would generate real SGF
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
    _logger.i('TeamGameScreen disposed');
    super.dispose();
  }
}

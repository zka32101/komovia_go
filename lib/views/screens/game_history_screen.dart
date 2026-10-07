import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/sgf_parser.dart';
import 'package:komovia_go/utils/go_board_geometry.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// Maps a GameRecord's result to the 3-way bucket ('win'/'loss'/'draw')
/// this screen filters and displays by. GameResult.resignation only ever
/// comes from the player in this app (the AI never resigns), so it's a
/// loss; GameResult.unknown falls back to 'draw' as a neutral default.
String _resultCategory(GameResult result) {
  switch (result) {
    case GameResult.playerWin:
      return 'win';
    case GameResult.aiWin:
    case GameResult.resignation:
      return 'loss';
    case GameResult.draw:
    case GameResult.unknown:
      return 'draw';
  }
}

/// GameHistoryScreen - Browse and replay past AI games
///
/// Features:
/// - View all completed games with scores and metadata
/// - Filter by result (win/loss/draw), AI level, date range
/// - Sort by date, score, duration
/// - Select game to view details and replay
/// - View final board state and move sequence
class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  String _filterResult = 'all'; // all, win, loss, draw
  String _sortBy = 'recent'; // recent, score, duration
  String? _selectedGameId;

  @override
  void initState() {
    super.initState();
    _logger.i('GameHistoryScreen initialized');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return _buildAuthRequiredState(context);
    }

    final gameRecords = ref.watch(userGameRecordsProvider(currentUser.uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.homeMyGamesTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterMenu(context),
            tooltip: l10n.filterTooltip,
          ),
        ],
      ),
      body: gameRecords.when(
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
        data: (games) {
          if (games.isEmpty) {
            return _buildEmptyState(context);
          }

          // Filter games
          var filteredGames = games;
          if (_filterResult != 'all') {
            filteredGames = filteredGames
                .where((g) => _resultCategory(g.result) == _filterResult)
                .toList();
          }

          // Sort games
          switch (_sortBy) {
            case 'score':
              filteredGames.sort((a, b) {
                final scoreA = (a.blackScore ?? 0) - (a.whiteScore ?? 0);
                final scoreB = (b.blackScore ?? 0) - (b.whiteScore ?? 0);
                return scoreB.compareTo(scoreA);
              });
              break;
            case 'duration':
              filteredGames.sort((a, b) =>
                  b.playedAt.compareTo(a.playedAt));
              break;
            case 'recent':
            default:
              filteredGames
                  .sort((a, b) => b.playedAt.compareTo(a.playedAt));
          }

          // The current filter may have excluded every game (or the
          // previously selected one); fall back to the list view instead
          // of crashing when there's nothing left to show details for.
          if (_selectedGameId == null || filteredGames.isEmpty) {
            return _buildGameList(context, filteredGames);
          }

          // If game selected, show details
          final selectedGame = filteredGames.firstWhere(
            (g) => g.id == _selectedGameId,
            orElse: () => filteredGames.first,
          );
          return _buildGameDetails(context, selectedGame, ref);
        },
      ),
    );
  }

  Widget _buildAuthRequiredState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.logInToViewGamesMessage,
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

  Widget _buildLoadingState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.kin),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.loadingYourGamesMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.shuLight,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.couldNotLoadGamesMessage,
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

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_esports,
            size: 64,
            color: AppColors.kin,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noGamesYetMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.playFirstGameMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
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

  Widget _buildGameList(BuildContext context, List<GameRecord> games) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeMyGamesTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.washi,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.gamesPlayedCountLabel(games.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                    context,
                    l10n.winsStatLabel,
                    games
                        .where((g) => _resultCategory(g.result) == 'win')
                        .length
                        .toString()),
                _buildStat(
                    context,
                    l10n.lossesStatLabel,
                    games
                        .where((g) => _resultCategory(g.result) == 'loss')
                        .length
                        .toString()),
                _buildStat(
                    context,
                    l10n.drawsStatLabel,
                    games
                        .where((g) => _resultCategory(g.result) == 'draw')
                        .length
                        .toString()),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Game list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: games.map((game) {
                return _buildGameCard(context, game);
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.kin,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(BuildContext context, GameRecord game) {
    final l10n = AppLocalizations.of(context)!;
    final category = _resultCategory(game.result);
    final isWin = category == 'win';
    final isDraw = category == 'draw';
    final borderColor = isWin
        ? AppColors.wakatake
        : isDraw
        ? AppColors.kin
        : AppColors.shuLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor ?? AppColors.sumiLine, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: InkWell(
        onTap: () => _handleSelectGame(context, game.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isWin
                      ? l10n.resultVictoryLabel
                      : isDraw
                      ? l10n.resultDrawLabel
                      : l10n.gameResultDefeatTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(l10n, game.playedAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Score and board info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.scoreLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.blackScore?.toStringAsFixed(1) ?? "?"} - ${game.whiteScore?.toStringAsFixed(1) ?? "?"}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.cardLevelLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.lvValueLabel(game.aiLevel),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.kin,
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
    );
  }

  Widget _buildGameDetails(BuildContext context, GameRecord game, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
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
                          _resultCategory(game.result) == 'win'
                              ? l10n.resultVictoryLabel
                              : _resultCategory(game.result) == 'draw'
                              ? l10n.resultDrawLabel
                              : l10n.gameResultDefeatTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.washi,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(l10n, game.playedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleBackToList(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.backButton),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Final board state
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 300,
                height: 300,
                foregroundDecoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.fuji,
                    width: 2,
                  ),
                ),
                decoration: BoxDecoration(
                  color: AppColors.kinLight.withOpacity(0.1),
                ),
                child: Builder(builder: (context) {
                  // game.sgfData is real move-order SGF (see sgf_parser.dart),
                  // so the final position is the replay of every move rather
                  // than BoardState.fromSgf's own final-snapshot-only dialect.
                  final moves = parseSgfMoves(game.sgfData);
                  final boardSize = parseSgfBoardSize(game.sgfData);
                  final stones = replaySgfMoves(moves, boardSize, moves.length);
                  final geometry = GoBoardGeometry(size: 300, boardSize: boardSize);
                  return Stack(
                    children: [
                      CustomPaint(
                        painter: GoBoardGridPainter(
                          boardSize: boardSize,
                          starPointColor: null,
                        ),
                        size: const Size(300, 300),
                      ),
                      ..._buildFinalStones(geometry, stones),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Game stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.sumiLine),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.washi.withOpacity(0.03),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.gameDetailsTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.washi,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(context, l10n.boardSizeLabel,
                      '${game.boardSize}×${game.boardSize}'),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      context,
                      l10n.aiLevelLabel,
                      l10n.levelLabel(game.aiLevel)),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      context,
                      l10n.finalScoreLabel,
                      '${game.blackScore?.toStringAsFixed(1) ?? "?"} - ${game.whiteScore?.toStringAsFixed(1) ?? "?"}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Move sequence
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMoveSequence(context, game),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildFinalStones(GoBoardGeometry geometry, List<List<int>> stones) {
    final stoneWidgets = <Widget>[];
    final stoneRadius = geometry.pitch * 0.4;

    for (int row = 0; row < geometry.boardSize; row++) {
      for (int col = 0; col < geometry.boardSize; col++) {
        final stone = stones[row][col];
        if (stone == 0) continue;
        final isBlack = stone == 1;
        final center = geometry.intersectionOffset(row, col);
        stoneWidgets.add(
          Positioned(
            left: center.dx - stoneRadius,
            top: center.dy - stoneRadius,
            child: GoStone(radius: stoneRadius, isBlack: isBlack),
          ),
        );
      }
    }
    return stoneWidgets;
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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

  Widget _buildMoveSequence(BuildContext context, GameRecord game) {
    final l10n = AppLocalizations.of(context)!;
    final moves = parseSgfMoves(game.sgfData);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.moveSequenceTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          if (moves.isEmpty)
            Text(
              l10n.noMoveDataMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.washiDim,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < moves.length; i++)
                  _buildMoveChip(l10n, i + 1, moves[i]),
              ],
            ),
        ],
      ),
    );
  }

  /// 1手を「17. Q16」のような棋譜表記で表示する小さなチップ。
  /// 列は伝統的な囲碁の座標表記に合わせ、Iを飛ばしたA〜Tを使う。
  Widget _buildMoveChip(AppLocalizations l10n, int moveNumber, SgfMove move) {
    const columnLetters = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';
    final label = move.isPass
        ? '$moveNumber. ${l10n.passButton}'
        : '$moveNumber. ${columnLetters[move.col]}${move.row + 1}';
    final isBlack = move.player == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlack ? AppColors.sumi : AppColors.washi.withOpacity(0.24),
        border: isBlack ? null : Border.all(color: AppColors.washiDim),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isBlack ? AppColors.washi : AppColors.sumi,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sumiSurface,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.filterByResultTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterOption(context, l10n.filterAllLabel, 'all'),
              _buildFilterOption(context, l10n.winsStatLabel, 'win'),
              _buildFilterOption(context, l10n.lossesStatLabel, 'loss'),
              _buildFilterOption(context, l10n.drawsStatLabel, 'draw'),
              const SizedBox(height: 24),
              Text(
                l10n.sortByTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
              const SizedBox(height: 12),
              _buildSortOption(context, l10n.sortMostRecentLabel, 'recent'),
              _buildSortOption(context, l10n.sortBestScoreLabel, 'score'),
              _buildSortOption(context, l10n.sortLongestLabel, 'duration'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, String label, String value) {
    return ListTile(
      title: Text(label),
      selected: _filterResult == value,
      onTap: () {
        setState(() => _filterResult = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSortOption(BuildContext context, String label, String value) {
    return ListTile(
      title: Text(label),
      selected: _sortBy == value,
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  void _handleSelectGame(BuildContext context, String gameId) {
    _logger.i('Selecting game: $gameId');
    setState(() => _selectedGameId = gameId);

    ref.read(logCustomEventProvider)(
      eventName: 'game_history_selected',
      parameters: {'game_id': gameId},
    );
  }

  void _handleBackToList() {
    _logger.i('Returning to game list');
    setState(() => _selectedGameId = null);
  }

  String _formatDate(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return l10n.todayLabel;
    } else if (dateOnly == yesterday) {
      return l10n.yesterdayLabel;
    } else if (dateOnly.year == today.year) {
      return '${dateOnly.month}/${dateOnly.day}';
    } else {
      return '${dateOnly.year}/${dateOnly.month}/${dateOnly.day}';
    }
  }
}

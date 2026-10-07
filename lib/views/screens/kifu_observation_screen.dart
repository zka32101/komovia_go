import 'dart:async';
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

/// KifuObservationScreen - Watch and learn from historical Go games
///
/// Features:
/// - Browse kifu library (historical games by famous players)
/// - Select game to watch from list
/// - Move-by-move replay with board visualization
/// - AI commentary on key moves
/// - Track observation progress and completion rate
/// - Filter by player, era, or difficulty
class KifuObservationScreen extends ConsumerStatefulWidget {
  const KifuObservationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KifuObservationScreen> createState() =>
      _KifuObservationScreenState();
}

class _KifuObservationScreenState extends ConsumerState<KifuObservationScreen> {
  late int _selectedRow;
  late int _selectedCol;
  int _currentMoveIndex = 0;
  String? _selectedGameId;
  int _totalMoves = 0;
  Timer? _autoplayTimer;
  int? _filterDifficulty;

  @override
  void initState() {
    super.initState();
    _logger.i('KifuObservationScreen initialized');
    _selectedRow = -1;
    _selectedCol = -1;
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final kifuLibrary = ref.watch(kifuLibraryProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.watchAndLearnTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterMenu(context),
            tooltip: l10n.filterTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
            tooltip: l10n.learnTooltip,
          ),
        ],
      ),
      body: kifuLibrary.when(
        loading: () => _buildLoadingState(context),
        error: (error, stack) => _buildErrorState(context, error),
        data: (games) {
          if (games.isEmpty) {
            return _buildEmptyState(context);
          }

          final filteredGames = _filterDifficulty == null
              ? games
              : games.where((g) => g.difficulty == _filterDifficulty).toList();

          // If no game selected, show library list
          if (_selectedGameId == null) {
            return filteredGames.isEmpty
                ? _buildNoMatchState(context)
                : _buildGameLibrary(context, filteredGames);
          }

          // If game selected, show replay interface
          final selectedGame = games
              .firstWhere((game) => game.id == _selectedGameId, orElse: () => games.first);
          return _buildGameReplay(context, selectedGame, ref);
        },
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
            l10n.loadingKifuLibraryMessage,
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
            Icons.library_books,
            size: 64,
            color: AppColors.kin,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noGamesAvailableMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkBackForHistoricalGamesMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
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

  Widget _buildNoMatchState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 64,
            color: AppColors.kin,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noGamesMatchFilterMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() => _filterDifficulty = null),
            child: Text(l10n.filterAllLabel),
          ),
        ],
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
                l10n.filterByDifficultyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.washi,
                ),
              ),
              const SizedBox(height: 12),
              _buildDifficultyFilterOption(context, l10n.filterAllLabel, null),
              for (var star = 1; star <= 5; star++)
                _buildDifficultyFilterOption(context, '★' * star + '☆' * (5 - star), star),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyFilterOption(BuildContext context, String label, int? value) {
    return ListTile(
      title: Text(label),
      selected: _filterDifficulty == value,
      onTap: () {
        setState(() => _filterDifficulty = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGameLibrary(BuildContext context, List<KifuLibrary> games) {
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
                  l10n.historicalGamesTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.washi,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.studyMasterGamesMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          ),

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

  Widget _buildGameCard(BuildContext context, KifuLibrary game) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: InkWell(
        onTap: () => _handleSelectGame(context, game.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game title and players
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.players.isNotEmpty
                            ? '${game.players[0]} vs ${game.players.length > 1 ? game.players[1] : "?"}'
                            : l10n.unknownPlayersLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.washiDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_outline,
                  size: 32,
                  color: AppColors.kin,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Game info
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildInfoItem(context, l10n.categoryLabel, _categoryText(context, game.category)),
                if (game.getDifficultyName() != null)
                  _buildInfoItem(context, l10n.difficultyLabel, game.getDifficultyName()!),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              game.source,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.washiDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryText(BuildContext context, KifuCategory c) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    switch (c) {
      case KifuCategory.copyrightFree:
        return ja ? '名局' : 'Classic games';
      case KifuCategory.ownGames:
        return ja ? '自分の対局' : 'My games';
      case KifuCategory.unknown:
        return ja ? 'その他' : 'Other';
    }
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washi,
          ),
        ),
      ],
    );
  }

  Widget _buildGameReplay(BuildContext context, KifuLibrary game, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final boardSize = parseSgfBoardSize(game.sgfData);
    final moves = parseSgfMoves(game.sgfData);
    _totalMoves = moves.length;
    if (_currentMoveIndex > _totalMoves) {
      _currentMoveIndex = _totalMoves;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Game header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.washi,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.players.isNotEmpty
                                ? game.players.join(' vs ')
                                : l10n.unknownPlayersLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.washiDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleBackToLibrary(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(l10n.backButton),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${_categoryText(context, game.category)} • ${game.source}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          ),

          // Game board
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildReplayBoard(context, boardSize, moves),
            ),
          ),

          const SizedBox(height: 32),

          // Move controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildMoveControls(context, moves.length),
          ),

          const SizedBox(height: 32),

          // Move commentary (placeholder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCommentarySection(context, boardSize, moves),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReplayBoard(BuildContext context, int boardSize, List<SgfMove> moves) {
    final stones = replaySgfMoves(moves, boardSize, _currentMoveIndex);
    final geometry = GoBoardGeometry(size: 300, boardSize: boardSize);

    return Container(
      width: 300,
      height: 300,
      // Frame is a foreground decoration so it does not inset the 300px
      // coordinate space shared by the grid and the stones.
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: AppColors.wakatake,
          width: 2,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.kinLight.withOpacity(0.1),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: GoBoardGridPainter(boardSize: boardSize),
            size: const Size(300, 300),
          ),
          ..._buildReplayStones(geometry, stones),
        ],
      ),
    );
  }

  List<Widget> _buildReplayStones(GoBoardGeometry geometry, List<List<int>> stones) {
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

  Widget _buildMoveControls(BuildContext context, int totalMoves) {
    final l10n = AppLocalizations.of(context)!;
    final sliderMax = totalMoves > 0 ? totalMoves : 1;
    final isPlaying = _autoplayTimer != null;

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
            l10n.moveProgressLabel(_currentMoveIndex, totalMoves),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),

          // Slider for move progress
          Slider(
            // _currentMoveIndex is kept within [0, _totalMoves] by the guard
            // in _buildGameReplay, so no extra clamping is needed here
            // (num.clamp() would return num, not double, and not typecheck).
            value: _currentMoveIndex.toDouble(),
            min: 0,
            max: sliderMax.toDouble(),
            divisions: sliderMax,
            label: '$_currentMoveIndex',
            activeColor: AppColors.kin,
            onChanged: totalMoves == 0
                ? null
                : (value) {
                    _stopAutoplay();
                    setState(() {
                      _currentMoveIndex = value.toInt();
                    });
                  },
          ),

          const SizedBox(height: 12),

          // Playback controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentMoveIndex > 0
                      ? () {
                          _stopAutoplay();
                          setState(() => _currentMoveIndex--);
                        }
                      : null,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.skip_previous),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.previousButton, maxLines: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: totalMoves == 0 ? null : () => _handleAutoplay(context, totalMoves),
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(isPlaying ? l10n.pauseButton : l10n.playButton, maxLines: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kin,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentMoveIndex < totalMoves
                      ? () {
                          _stopAutoplay();
                          setState(() => _currentMoveIndex++);
                        }
                      : null,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.skip_next),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.nextButton, maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Move-by-move notes derived from the position itself (no engine needed):
  /// who played where, what was captured and the running stone count.
  String _commentaryFor(BuildContext context, int boardSize, List<SgfMove> moves) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final index = _currentMoveIndex;
    if (index <= 0 || moves.isEmpty) {
      return ja
          ? 'スライダーか「次へ」で手を進めると、一手ごとの着手と取った石の数がここに表示されます。'
          : 'Step through the game to see each move and any captures here.';
    }
    int count(List<List<int>> g, int who) =>
        g.fold(0, (a, r) => a + r.where((v) => v == who).length);
    final before = replaySgfMoves(moves, boardSize, index - 1);
    final after = replaySgfMoves(moves, boardSize, index);
    final move = moves[index - 1];
    final isBlack = move.player == 1;
    final who = ja ? (isBlack ? '黒' : '白') : (isBlack ? 'Black' : 'White');
    final opp = isBlack ? 2 : 1;
    final captured = count(before, opp) - count(after, opp);
    final blackNow = count(after, 1);
    final whiteNow = count(after, 2);
    final board = ja
        ? '盤上: 黒$blackNow子 / 白$whiteNow子'
        : 'On board: Black $blackNow / White $whiteNow';
    if (move.isPass) {
      return ja ? '$index手目: $whoはパスしました。\n$board' : 'Move $index: $who passed.\n$board';
    }
    const letters = 'ABCDEFGHJKLMNOPQRST';
    final coord = '${letters[move.col]}${boardSize - move.row}';
    final String cap;
    if (captured <= 0) {
      cap = '';
    } else if (ja) {
      cap = '\n相手の石を$captured子取りました。';
    } else {
      cap = '\nCaptured $captured ${captured == 1 ? "stone" : "stones"}.';
    }
    return ja
        ? '$index手目: $whoが$coordに打ちました。$cap\n$board'
        : 'Move $index: $who played $coord.$cap\n$board';
  }

  Widget _buildCommentarySection(BuildContext context, int boardSize, List<SgfMove> moves) {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.commentaryTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _commentaryFor(context, boardSize, moves),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.aboutKifuObservationTitle),
        content: Text(l10n.aboutKifuObservationContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotItButton),
          ),
        ],
      ),
    );
  }

  void _handleSelectGame(BuildContext context, String gameId) {
    _logger.i('Selecting game: $gameId');
    setState(() {
      _selectedGameId = gameId;
      _currentMoveIndex = 0;
    });

    ref.read(logCustomEventProvider)(
      eventName: 'kifu_selected',
      parameters: {'game_id': gameId},
    );
  }

  void _handleBackToLibrary() {
    _logger.i('Returning to library');
    _stopAutoplay();

    final currentUser = ref.read(currentUserProvider);
    final gameId = _selectedGameId;
    if (currentUser != null && gameId != null && _totalMoves > 0) {
      final completedRate = _currentMoveIndex / _totalMoves;
      ref
          .read(saveObservationLogProvider)(
            uid: currentUser.uid,
            kifuId: gameId,
            completedRate: completedRate,
          )
          .catchError((e) {
            _logger.e('❌ Failed to save observation log: $e');
            return '';
          });
    }

    setState(() {
      _selectedGameId = null;
      _currentMoveIndex = 0;
      _totalMoves = 0;
    });
  }

  void _handleAutoplay(BuildContext context, int totalMoves) {
    if (_autoplayTimer != null) {
      _stopAutoplay();
      return;
    }

    _logger.i('Starting autoplay from move $_currentMoveIndex');
    _autoplayTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_currentMoveIndex >= totalMoves) {
        _stopAutoplay();
        return;
      }
      setState(() => _currentMoveIndex++);
    });
    setState(() {});
  }

  void _stopAutoplay() {
    if (_autoplayTimer == null) return;
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
    if (mounted) setState(() {});
  }
}

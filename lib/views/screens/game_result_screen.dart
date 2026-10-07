import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/index.dart';
import 'package:komovia_go/services/index.dart' show GameAnalysis;
import 'package:komovia_go/utils/shoji_transition.dart';
import 'package:komovia_go/utils/sgf_parser.dart';
import 'ai_game_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// GameResultScreen - Post-game summary and analysis
///
/// Displays:
/// - Final score with Chinese rules
/// - Winner determination
/// - Move-by-move analysis (powered by AI)
/// - Stats (duration, moves, difficulty)
/// - Options to save game or play again
class GameResultScreen extends ConsumerWidget {
  final String result; // 'win', 'lose', 'draw', 'resign'
  final double? blackScore;
  final double? whiteScore;

  const GameResultScreen({
    Key? key,
    required this.result,
    this.blackScore,
    this.whiteScore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building GameResultScreen: result=$result');
    final l10n = AppLocalizations.of(context)!;

    // 実績解除トースト: _checkAndRecordAchievements（game_provider.dart、
    // 「対局を保存」タップ後にbest-effortで実行される）が新規解除実績を
    // 検出したら、ここで拾って一度だけ表示する。届いた時にはこの画面が
    // 既にビルド済みのはずなのでpostFrameCallbackでSnackBar表示、表示後は
    // 同じ実績を二重に見せないようプロバイダーを空に戻す。
    ref.listen<List<Achievement>>(newlyUnlockedAchievementsProvider, (previous, next) {
      if (next.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _showAchievementUnlockedSnackBar(context, l10n, next);
      });
      ref.read(newlyUnlockedAchievementsProvider.notifier).state = [];
    });

    // 対局終了時のインタースティシャル広告。何度も再ビルドされる画面
    // なので、フラグで一度だけに制限する（プレミアム会員には出さない
    // 判定はshowGameEndInterstitialProvider側で行う）。フラグの読み書き
    // はbuild中ではなくpostFrameCallback内で行う（Riverpodはbuild中の
    // プロバイダー変更を許可しないため）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(hasShownGameEndAdProvider)) {
        ref.read(hasShownGameEndAdProvider.notifier).state = true;
        ref.read(showGameEndInterstitialProvider)();
      }
    });

    final boardState = ref.watch(gameBoardStateProvider);
    final aiLevel = ref.watch(aiLevelProvider);
    final movesCount = ref.watch(movesCountProvider);
    final currentUser = ref.watch(currentUserProvider);
    final savedGameId = ref.watch(currentGameSavedIdProvider);

    // Determine winner
    final winner = _determineWinner(
      result,
      blackScore ?? 0,
      whiteScore ?? 0,
    );

    // 保存済みの実際のgame IDが無いと、共有した相手が開くdeepLinkが
    // 存在しない対局を指してしまう(過去のバグ)。未保存の間はシェア
    // ボタンをタップすると先に保存してから共有ダイアログを出す。
    Widget shareFab;
    if (savedGameId != null) {
      final gameShareData = GameShareData(
        gameId: savedGameId,
        result: winner == 'player' ? 'win' : winner == 'ai' ? 'loss' : 'draw',
        blackScore: blackScore ?? 0,
        whiteScore: whiteScore ?? 0,
        boardSize: boardState.boardSize,
        aiLevel: aiLevel,
      );
      shareFab = GameShareButton(
        gameData: gameShareData,
        onShared: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.gameSharedSuccessMessage)),
          );
        },
      );
    } else {
      shareFab = FloatingActionButton.extended(
        onPressed: () async {
          await _handleSaveGame(context, ref, l10n, currentUser);
          if (!context.mounted) return;
          if (ref.read(currentGameSavedIdProvider) != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.savedPromptShareAgainMessage)),
            );
          }
        },
        icon: const Icon(Icons.share),
        label: Text(l10n.shareButton),
        backgroundColor: AppColors.kin,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.sumi,
      floatingActionButton: shareFab,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // Result header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Win/lose indicator
                    _maybeWithVictoryGlow(
                      isVictory: winner == 'player',
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: winner == 'player'
                              ? AppColors.wakatake.withOpacity(0.2)
                              : winner == 'ai'
                              ? AppColors.shuLight.withOpacity(0.2)
                              : AppColors.kin.withOpacity(0.2),
                          border: Border.all(
                            color: winner == 'player'
                                ? AppColors.wakatake
                                : winner == 'ai'
                                ? AppColors.shuLight
                                : AppColors.kin,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          winner == 'player'
                              ? Icons.emoji_events
                              : winner == 'ai'
                              ? Icons.sentiment_dissatisfied
                              : Icons.balance,
                          size: 50,
                          color: winner == 'player'
                              ? AppColors.wakatake
                              : winner == 'ai'
                              ? AppColors.shuLight
                              : AppColors.kin,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Result text
                    Text(
                      _getResultTitle(l10n, winner),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _getResultSubtitle(l10n, result),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.washiDim,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Score section
              if (result != 'resign')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildScoreSection(
                    context,
                    l10n,
                    blackScore ?? 0,
                    whiteScore ?? 0,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.sumiLine),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.washi.withOpacity(0.03),
                    ),
                    child: Text(
                      l10n.gameResignedMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.washiDim,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Game stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildStatsSection(
                  context,
                  l10n,
                  boardSize: boardState.boardSize,
                  aiLevel: aiLevel,
                  movesCount: movesCount,
                ),
              ),

              const SizedBox(height: 32),

              // AI commentary (if available)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _AiReviewSection(
                  // Real move-order SGF (see sgf_parser.dart), not
                  // boardState.toSgf()'s final-snapshot-only dialect —
                  // the AI review needs the actual move sequence to
                  // explain individual moves, not just the end position.
                  sgfData: generateSgfFromMoves(
                    ref.watch(moveHistoryProvider),
                    boardState.boardSize,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handleSaveGame(context, ref, l10n, currentUser),
                        child: Text(l10n.saveGameButton),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handlePlayAgain(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kin,
                        ),
                        child: Text(
                          l10n.playAgainButton,
                          style: TextStyle(
                            color: AppColors.sumi,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleUploadToYouTube(
                          context,
                          ref,
                          l10n,
                          currentUser,
                          boardState,
                        ),
                        icon: const Icon(Icons.ondemand_video),
                        label: Text(l10n.youtubeUploadButton),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _handleBackToHome(context),
                        child: Text(l10n.backToHomeButton),
                      ),
                    ),
                  ],
                ),
              ),

              // Leave room so the floating share button never covers the
              // last action button once scrolled to the end.
              const SizedBox(height: 104),
            ],
          ),
        ),
      ),
    );
  }

  /// 勝った時だけ、勝敗アイコンにゆっくり明滅する後光を付ける。
  Widget _maybeWithVictoryGlow({required bool isVictory, required Widget child}) {
    if (!isVictory) return child;
    return _VictoryGlow(child: child);
  }

  /// Score section showing final positions
  Widget _buildScoreSection(
    BuildContext context,
    AppLocalizations l10n,
    double blackScore,
    double whiteScore,
  ) {
    final blackWins = blackScore > whiteScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        children: [
          Text(
            l10n.finalScoreTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sumi,
                      border: Border.all(
                        color: blackWins ? AppColors.wakatake : AppColors.grey500,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.blackYouLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.washi,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    blackScore.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    'vs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.washiDim,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.washi,
                      border: Border.all(
                        color: !blackWins ? AppColors.shuLight : Colors.black26,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        l10n.whiteAiLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.sumi,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    whiteScore.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
    );
  }

  /// Stats section
  Widget _buildStatsSection(
    BuildContext context,
    AppLocalizations l10n, {
    required int boardSize,
    required int aiLevel,
    required int movesCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        children: [
          Text(
            l10n.gameStatsTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, l10n.boardLabel, '${boardSize}×$boardSize'),
              _buildStatItem(context, l10n.aiLevelLabel, '$aiLevel'),
              _buildStatItem(context, l10n.movesLabel, '$movesCount'),
            ],
          ),
        ],
      ),
    );
  }

  /// Single stat item
  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.washiDim,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.kin,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getResultTitle(AppLocalizations l10n, String? winner) {
    switch (winner) {
      case 'player':
        return l10n.gameResultVictoryTitle;
      case 'ai':
        return l10n.gameResultDefeatTitle;
      default:
        return l10n.gameResultGameOverTitle;
    }
  }

  String _getResultSubtitle(AppLocalizations l10n, String result) {
    switch (result) {
      case 'resign':
        return l10n.gameResultResignSubtitle;
      case 'draw':
        return l10n.gameResultDrawSubtitle;
      default:
        return l10n.gameResultDefaultSubtitle;
    }
  }

  String? _determineWinner(String result, double blackScore, double whiteScore) {
    if (result == 'resign') return 'ai';
    if (blackScore > whiteScore) return 'player';
    if (whiteScore > blackScore) return 'ai';
    return 'draw';
  }

  Future<void> _handleSaveGame(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    User? currentUser,
  ) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseLoginToSaveMessage)),
      );
      return;
    }

    _logger.i('Saving game...');
    final boardState = ref.read(gameBoardStateProvider);

    try {
      final gameId = await ref.read(saveGameRecordProvider)(
        uid: currentUser.uid,
        boardSize: boardState.boardSize,
        result: result,
        blackScore: blackScore,
        whiteScore: whiteScore,
      );
      _logger.i('✅ Game saved: $gameId');
      ref.read(currentGameSavedIdProvider.notifier).state = gameId;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.gameSavedMessage)),
      );
    } catch (e) {
      _logger.e('❌ Failed to save game: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToSaveGameMessage('$e'))),
      );
    }
  }

  /// YouTubeへのアップロードは実際のOAuth/APIバックエンドが存在しない
  /// （Firestoreへのブックキーピングのみ — youtube_share_screen.dartの
  /// 「接続する」ボタンと同じ理由・同じ正直な「まだ使えません」ダイアログ）
  /// ため、isYouTubeConnectedが true になることは実質無い。それでも
  /// GameResultScreenから対局を直接アップロードする入口自体は実装し、
  /// 接続済みになった場合にそのまま使えるようにしておく。
  Future<void> _handleUploadToYouTube(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    User? currentUser,
    BoardState boardState,
  ) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseLoginToSaveMessage)),
      );
      return;
    }

    // アップロードは実在するgameIdを指す必要があるため、未保存ならまず保存する。
    if (ref.read(currentGameSavedIdProvider) == null) {
      await _handleSaveGame(context, ref, l10n, currentUser);
      if (!context.mounted) return;
    }
    final gameId = ref.read(currentGameSavedIdProvider);
    if (gameId == null) return; // 保存失敗。_handleSaveGame側で既に通知済み。

    final isConnected =
        await ref.read(youtubeShareServiceProvider).isYouTubeConnected(currentUser.uid);
    if (!context.mounted) return;

    if (!isConnected) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.sumiSurface,
          title: Text(l10n.youtubeComingSoonTitle),
          content: Text(l10n.youtubeComingSoonMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.closeButton),
            ),
          ],
        ),
      );
      return;
    }

    final movesCount = ref.read(movesCountProvider);
    final moves = ref
        .read(moveHistoryProvider)
        .map((m) => m.row < 0 ? -1 : m.row * boardState.boardSize + m.col)
        .toList();

    try {
      final uploadResult = await ref.read(uploadToYouTubeProvider)(
        YouTubeShareData(
          userId: currentUser.uid,
          gameId: gameId,
          title: l10n.youtubeUploadTitle(boardState.boardSize),
          description: l10n.youtubeUploadDescription(movesCount),
          moves: moves,
        ),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadResult != null ? l10n.youtubeUploadStartedMessage : l10n.genericErrorMessage,
          ),
        ),
      );
    } catch (e) {
      _logger.e('❌ Failed to upload to YouTube: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericErrorMessage)),
      );
    }
  }

  void _handlePlayAgain(BuildContext context, WidgetRef ref) {
    _logger.i('Playing again...');
    // gameBoardStateProvider etc. are plain globals, not scoped to
    // AIGameScreen's lifecycle — without this, the new game would start
    // by showing the just-finished board instead of an empty one.
    ref.read(startNewGameProvider)();
    Navigator.of(context).pushReplacement(shojiTransitionRoute(const AIGameScreen()));
  }

  void _handleBackToHome(BuildContext context) {
    _logger.i('Returning to home...');
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _showAchievementUnlockedSnackBar(
    BuildContext context,
    AppLocalizations l10n,
    List<Achievement> unlocked,
  ) {
    for (final achievement in unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.sumiSurface,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Text(achievement.iconEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.achievementUnlockedLabel,
                      style: const TextStyle(color: AppColors.kin, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      achievement.name,
                      style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// AI振り返り（対局後レビュー） - ボタン押下でCloud Functionsを呼び、
/// 手ごとの解説と局面の総評を表示する。時間のかかる処理なので画面表示時に
/// 自動実行はせず、ユーザーの明示的な操作で開始する。
class _AiReviewSection extends ConsumerStatefulWidget {
  final String sgfData;

  const _AiReviewSection({required this.sgfData});

  @override
  ConsumerState<_AiReviewSection> createState() => _AiReviewSectionState();
}

class _AiReviewSectionState extends ConsumerState<_AiReviewSection> {
  GameAnalysis? _analysis;
  bool _loading = false;
  String? _error;

  Future<void> _runReview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analysis = await ref.read(generateGameAnalysisProvider)(
        sgfData: widget.sgfData,
        kifuId: 'review-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = l10n.aiReviewFailedMessage('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            l10n.aiReviewTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.washi),
          ),
          const SizedBox(height: 12),
          if (_analysis == null && !_loading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiReviewPrompt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.washiDim,
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _runReview,
                    child: Text(l10n.aiReviewButton),
                  ),
                ),
              ],
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          if (_analysis != null) _buildAnalysis(context, l10n, _analysis!),
        ],
      ),
    );
  }

  Widget _buildAnalysis(BuildContext context, AppLocalizations l10n, GameAnalysis analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          analysis.overallTheme,
          style: const TextStyle(color: AppColors.washi, height: 1.6),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.turningPointLabel(analysis.keyTurningPoints),
          style: TextStyle(color: AppColors.washiDim, height: 1.6),
        ),
        const SizedBox(height: 8),
        Text(
          analysis.conclusion,
          style: TextStyle(color: AppColors.washiDim, height: 1.6),
        ),
        const SizedBox(height: 16),
        for (final move in analysis.moves) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.moveExplanationLine(
                move.moveNumber,
                move.playerColor == 'black' ? l10n.colorBlackLabel : l10n.colorWhiteLabel,
                move.row,
                move.col,
                move.basicExplanation,
              ),
              style: TextStyle(color: AppColors.washiDim, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

/// 勝利時のトロフィーアイコンをゆっくり明滅させる、控えめな祝福演出。
/// ゲームらしい楽しさを足す一方、派手な紙吹雪などは「大人向けプレミアム」
/// というトーンに合わないため、光量が上下するだけのシンプルな後光に留める。
class _VictoryGlow extends StatefulWidget {
  final Widget child;

  const _VictoryGlow({required this.child});

  @override
  State<_VictoryGlow> createState() => _VictoryGlowState();
}

class _VictoryGlowState extends State<_VictoryGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = 0.25 + _controller.value * 0.35;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.kin.withOpacity(glow),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

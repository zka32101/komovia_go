import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/index.dart';
import '../../viewmodels/index.dart';
import 'share_dialog.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

String _successMessage(AppLocalizations l10n, SocialPlatform platform) =>
    platform == SocialPlatform.clipboard
        ? l10n.shareCopiedMessage
        : l10n.shareSucceededMessage(platform.displayName);

/// Widget for sharing game results
class GameShareButton extends ConsumerWidget {
  final GameShareData gameData;
  final VoidCallback? onShared;

  const GameShareButton({
    Key? key,
    required this.gameData,
    this.onShared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showShareDialog(context, ref),
      icon: const Icon(Icons.share),
      label: Text(AppLocalizations.of(context)!.shareButton),
      backgroundColor: AppColors.kin,
    );
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ShareDialog(
        content: _generateShareContent(AppLocalizations.of(context)!),
        onShare: (platform) => _handleShare(context, ref, platform),
      ),
    );
  }

  ShareContent _generateShareContent(AppLocalizations l10n) {
    final won = gameData.result == 'win';
    final resultEmoji = won ? '🎉' : '💪';
    final boardSizeEmoji = _getBoardSizeEmoji(gameData.boardSize);

    final text = '''
$resultEmoji ${won ? l10n.shareGameWon : l10n.shareGameChallenged}

$boardSizeEmoji ${l10n.shareBoardSize(gameData.boardSize)}
🤖 ${l10n.shareAiLevel(gameData.aiLevel)}
⚫ ${l10n.shareBlackScore('${gameData.blackScore}')}
⚪ ${l10n.shareWhiteScore('${gameData.whiteScore}')}

${l10n.shareGameHashtagsFull}
'''.trim();

    return ShareContent(
      text: text,
      hashtags: l10n.shareGameHashtags,
      deepLink: 'goen://game/${gameData.gameId}',
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    SocialPlatform platform,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final content = _generateShareContent(l10n);
    final success = await ref.read(
      shareWithPlatformProvider((content: content, platform: platform)).future,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_successMessage(l10n, platform))),
      );
      onShared?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareFailedMessage)),
      );
    }
  }

  String _getBoardSizeEmoji(int boardSize) {
    switch (boardSize) {
      case 9:
        return '📦';
      case 13:
        return '📋';
      case 19:
        return '🎴';
      default:
        return '🎲';
    }
  }
}

/// Widget for sharing puzzle achievements
class PuzzleShareButton extends ConsumerWidget {
  final PuzzleShareData puzzleData;
  final VoidCallback? onShared;

  const PuzzleShareButton({
    Key? key,
    required this.puzzleData,
    this.onShared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showShareDialog(context, ref),
      icon: const Icon(Icons.share),
      label: Text(AppLocalizations.of(context)!.shareButton),
      backgroundColor: AppColors.aiLight,
    );
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ShareDialog(
        content: _generateShareContent(AppLocalizations.of(context)!),
        onShare: (platform) => _handleShare(context, ref, platform),
      ),
    );
  }

  ShareContent _generateShareContent(AppLocalizations l10n) {
    final difficultyEmoji = _getDifficultyEmoji(puzzleData.difficulty);
    final achievementEmoji = puzzleData.isSolved ? '✨' : '💭';

    final text = '''
$achievementEmoji ${puzzleData.isSolved ? l10n.sharePuzzleSolved : l10n.sharePuzzleChallenged}

$difficultyEmoji ${l10n.shareDifficulty(_getDifficultyLabel(l10n, puzzleData.difficulty))}
🎯 ${l10n.shareAttempts(puzzleData.attemptCount)}
⏱️ ${l10n.shareSolveTime(_formatDuration(l10n, puzzleData.solvingTime))}
🔥 ${l10n.shareStreak(puzzleData.currentStreak)}

${l10n.sharePuzzleHashtagsFull}
'''.trim();

    return ShareContent(
      text: text,
      hashtags: l10n.sharePuzzleHashtags,
      deepLink: 'goen://puzzle/${puzzleData.puzzleId}',
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    SocialPlatform platform,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final content = _generateShareContent(l10n);
    final success = await ref.read(
      shareWithPlatformProvider((content: content, platform: platform)).future,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_successMessage(l10n, platform))),
      );
      onShared?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareFailedMessage)),
      );
    }
  }

  String _getDifficultyEmoji(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'hard':
        return '🔴';
      case 'master':
        return '⚫';
      default:
        return '⭐';
    }
  }

  String _getDifficultyLabel(AppLocalizations l10n, String difficulty) {
    final labels = {
      'easy': l10n.shareDifficultyEasy,
      'medium': l10n.shareDifficultyMedium,
      'hard': l10n.shareDifficultyHard,
      'master': l10n.shareDifficultyMaster,
    };
    return labels[difficulty] ?? difficulty;
  }

  String _formatDuration(AppLocalizations l10n, Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes == 0) {
      return l10n.shareDurationSeconds(seconds);
    }
    return l10n.shareDurationMinutes(minutes, seconds);
  }
}

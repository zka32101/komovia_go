import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/index.dart';
import '../../viewmodels/index.dart';
import 'share_dialog.dart';
import 'package:komovia_go/config/theme.dart';

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
      label: const Text('シェア'),
      backgroundColor: AppColors.kin,
    );
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ShareDialog(
        content: _generateShareContent(),
        onShare: (platform) => _handleShare(context, ref, platform),
      ),
    );
  }

  ShareContent _generateShareContent() {
    final resultEmoji = gameData.result == 'win' ? '🎉' : '💪';
    final boardSizeEmoji = _getBoardSizeEmoji(gameData.boardSize);

    final text = '''
$resultEmoji 今碁で${gameData.result == 'win' ? '勝利' : '挑戦'}しました！

$boardSizeEmoji ${gameData.boardSize}路盤
🤖 AI レベル: ${gameData.aiLevel}
⚫ 黒: ${gameData.blackScore}目
⚪ 白: ${gameData.whiteScore}目

#碁 #Go #碁縁 #AI碁 #オンライン碁
'''.trim();

    return ShareContent(
      text: text,
      hashtags: '#碁 #Go #碁縁',
      deepLink: 'goen://game/${gameData.gameId}',
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    SocialPlatform platform,
  ) async {
    final content = _generateShareContent();
    final success = await ref.read(
      shareWithPlatformProvider((content: content, platform: platform)).future,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${platform.displayName}で共有しました')),
      );
      onShared?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('シェアに失敗しました')),
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
      label: const Text('シェア'),
      backgroundColor: AppColors.aiLight,
    );
  }

  void _showShareDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ShareDialog(
        content: _generateShareContent(),
        onShare: (platform) => _handleShare(context, ref, platform),
      ),
    );
  }

  ShareContent _generateShareContent() {
    final difficultyEmoji = _getDifficultyEmoji(puzzleData.difficulty);
    final achievementEmoji = puzzleData.isSolved ? '✨' : '💭';

    final text = '''
$achievementEmoji 詰碁に${puzzleData.isSolved ? '成功' : 'チャレンジ'}しました！

$difficultyEmoji 難易度: ${_getDifficultyLabel(puzzleData.difficulty)}
🎯 試行回数: ${puzzleData.attemptCount}回
⏱️ 解答時間: ${_formatDuration(puzzleData.solvingTime)}
🔥 連続成功: ${puzzleData.currentStreak}問

#詰碁 #碁 #碁縁 #AI解説
'''.trim();

    return ShareContent(
      text: text,
      hashtags: '#詰碁 #碁 #碁縁',
      deepLink: 'goen://puzzle/${puzzleData.puzzleId}',
    );
  }

  Future<void> _handleShare(
    BuildContext context,
    WidgetRef ref,
    SocialPlatform platform,
  ) async {
    final content = _generateShareContent();
    final success = await ref.read(
      shareWithPlatformProvider((content: content, platform: platform)).future,
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${platform.displayName}で共有しました')),
      );
      onShared?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('シェアに失敗しました')),
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

  String _getDifficultyLabel(String difficulty) {
    const labels = {
      'easy': '初級',
      'medium': '中級',
      'hard': '上級',
      'master': 'マスター',
    };
    return labels[difficulty] ?? difficulty;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes == 0) {
      return '${seconds}秒';
    }
    return '$minutes分${seconds}秒';
  }
}

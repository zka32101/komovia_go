import 'package:riverpod/riverpod.dart';
import '../models/social_share_models.dart';
import '../services/social_share_service.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Provider for SocialShareService
final socialShareServiceProvider = Provider<SocialShareService>((ref) {
  return const SocialShareService();
});

/// Generate share content from game data
final gameResultShareContentProvider = Provider.family<
    ShareContent,
    GameShareData>((ref, gameData) {
  return _generateGameResultShareContent(gameData);
});

/// Share game result to specific platform
final shareGameResultProvider =
    FutureProvider.family<bool, (GameShareData, SocialPlatform)>(
  (ref, params) async {
    final (gameData, platform) = params;
    final shareService = ref.watch(socialShareServiceProvider);
    final content = ref.watch(gameResultShareContentProvider(gameData));

    try {
      _logger.i('Sharing game result to ${platform.displayName}');
      final result = await shareService.shareWithPlatform(
        content,
        platform: platform,
      );
      return result;
    } catch (e) {
      _logger.e('Failed to share game result: $e');
      return false;
    }
  },
);

/// Generate share content for game results
ShareContent _generateGameResultShareContent(GameShareData gameData) {
  final resultText = _getResultText(gameData.result);
  final scoreStr = '${gameData.blackScore.toStringAsFixed(1)} vs '
      '${gameData.whiteScore.toStringAsFixed(1)}';

  final text = '''🎮 Just finished a Go game!
$resultText
Score: $scoreStr
Board: ${gameData.boardSize}×${gameData.boardSize}
Difficulty: Level ${gameData.aiLevel}
${gameData.sgfUrl != null ? 'Watch: ${gameData.sgfUrl}' : ''}''';

  return ShareContent(
    text: text,
    hashtags: '#GoGame #碁縁 #GoEn #AIGo #GoPuzzle',
    imageUrl: gameData.includeImage ? gameData.sgfUrl : null,
    deepLink: 'goen://game/${gameData.gameId}',
  );
}

/// Generate share content for puzzle achievements
ShareContent generatePuzzleShareContent(PuzzleShareData puzzleData) {
  final statusText = puzzleData.isSolved
      ? '✅ Successfully solved!'
      : '⏳ Still working on it...';

  final text = '''🧩 Puzzle Achievement!
Difficulty: ${puzzleData.difficulty}
$statusText
Attempts: ${puzzleData.attemptCount}
Time: ${puzzleData.solvingTime.inMinutes}m ${puzzleData.solvingTime.inSeconds % 60}s''';

  if (puzzleData.isSolved) {
    return ShareContent(
      text: '$text\n\n🔥 Current Streak: ${puzzleData.currentStreak}',
      hashtags: '#TsumeGo #GoEn #PuzzleSolved #碁',
      deepLink: 'goen://puzzle/${puzzleData.puzzleId}',
    );
  }

  return ShareContent(
    text: text,
    hashtags: '#TsumeGo #GoEn #GoPuzzle',
    deepLink: 'goen://puzzle/${puzzleData.puzzleId}',
  );
}

/// Generate share content for profile
ShareContent generateProfileShareContent(ProfileShareData profileData) {
  final winRate = profileData.totalGamesPlayed > 0
      ? (profileData.winCount / profileData.totalGamesPlayed * 100)
          .toStringAsFixed(1)
      : '0.0';

  final text = '''👤 ${profileData.displayName}'s Go Profile
📊 Games: ${profileData.totalGamesPlayed}
🏆 Wins: ${profileData.winCount} (${winRate}%)
🧩 Puzzles Solved: ${profileData.totalPuzzlesSolved}
🔥 Puzzle Streak: ${profileData.currentPuzzleStreak}

Playing on GoEn 棋縁''';

  return ShareContent(
    text: text,
    hashtags: '#GoEn #碁縁 #GoGame #AIGo',
    imageUrl: profileData.profileImageUrl,
    deepLink: 'goen://profile/${profileData.userId}',
  );
}

String _getResultText(String result) {
  switch (result) {
    case 'win':
      return '🎉 Victory! Opponent Resigned';
    case 'loss':
      return '😌 Graceful Defeat - Learning Moment';
    case 'draw':
      return '⚖️ Even Match - Well Played!';
    default:
      return '⚫⚪ Game Complete';
  }
}

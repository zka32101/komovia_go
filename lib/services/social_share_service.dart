import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
import '../models/social_share_models.dart';

final _logger = Logger();

/// Service for sharing content to social platforms
class SocialShareService {
  const SocialShareService();

  /// Share game result to Twitter/X
  /// Returns true if share was successful
  Future<bool> shareGameToTwitter(GameShareData gameData) async {
    try {
      final content = _generateGameShareContent(gameData);
      return await _shareToTwitter(content);
    } catch (e) {
      _logger.e('Failed to share game to Twitter: $e');
      return false;
    }
  }

  /// Share puzzle achievement to Twitter/X
  Future<bool> sharePuzzleToTwitter(PuzzleShareData puzzleData) async {
    try {
      final content = _generatePuzzleShareContent(puzzleData);
      return await _shareToTwitter(content);
    } catch (e) {
      _logger.e('Failed to share puzzle to Twitter: $e');
      return false;
    }
  }

  /// Share profile/progress to Twitter/X
  Future<bool> shareProfileToTwitter(ProfileShareData profileData) async {
    try {
      final content = _generateProfileShareContent(profileData);
      return await _shareToTwitter(content);
    } catch (e) {
      _logger.e('Failed to share profile to Twitter: $e');
      return false;
    }
  }

  /// Generic share using platform share sheet
  Future<bool> shareWithPlatform(
    ShareContent content, {
    required SocialPlatform platform,
  }) async {
    try {
      switch (platform) {
        case SocialPlatform.twitter:
          return await _shareToTwitter(content);
        case SocialPlatform.facebook:
          return await _shareToFacebook(content);
        case SocialPlatform.whatsapp:
          return await _shareToWhatsApp(content);
        case SocialPlatform.line:
          return await _shareToLine(content);
        case SocialPlatform.clipboard:
          return await _copyToClipboard(content);
      }
    } catch (e) {
      _logger.e('Failed to share via $platform: $e');
      return false;
    }
  }

  /// Share via system share sheet
  Future<bool> shareGeneric(ShareContent content) async {
    try {
      // share_plus 7.x's Share.share() returns void (only shareWithResult()
      // reports the outcome) — reaching here without throwing means the
      // share sheet was presented successfully.
      await Share.share(
        content.text,
        subject: content.appName,
      );
      return true;
    } catch (e) {
      _logger.e('Failed to share: $e');
      return false;
    }
  }

  // Private methods for platform-specific sharing

  Future<bool> _shareToTwitter(ShareContent content) async {
    try {
      // content.text already ends with its own hashtag line (see the
      // _generate*ShareContent methods below) — appending content.hashtags
      // here would duplicate them in the tweet.
      final text = Uri.encodeComponent(content.text);
      final twitterUrl = Uri.parse('https://twitter.com/intent/tweet?text=$text');

      if (await canLaunchUrl(twitterUrl)) {
        await launchUrl(twitterUrl, mode: LaunchMode.externalApplication);
        return true;
      } else {
        _logger.w('Twitter app not installed, trying web fallback');
        return await launchUrl(twitterUrl);
      }
    } catch (e) {
      _logger.e('Twitter share failed: $e');
      return false;
    }
  }

  Future<bool> _shareToFacebook(ShareContent content) async {
    try {
      final facebookUrl = Uri.parse(
        'fb://dialog/share?app_id=YOUR_APP_ID&href=${Uri.encodeComponent(content.deepLink ?? 'https://yourapp.com')}&redirect_uri=https://yourapp.com',
      );

      if (await canLaunchUrl(facebookUrl)) {
        return await launchUrl(facebookUrl);
      }
      return false;
    } catch (e) {
      _logger.e('Facebook share failed: $e');
      return false;
    }
  }

  Future<bool> _shareToWhatsApp(ShareContent content) async {
    try {
      final whatsappUrl = Uri.parse(
        'whatsapp://send?text=${Uri.encodeComponent(content.text)}',
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('WhatsApp share failed: $e');
      return false;
    }
  }

  Future<bool> _shareToLine(ShareContent content) async {
    try {
      final lineUrl = Uri.parse(
        'line://msg/text/${Uri.encodeComponent(content.text)}',
      );

      if (await canLaunchUrl(lineUrl)) {
        await launchUrl(lineUrl);
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('LINE share failed: $e');
      return false;
    }
  }

  Future<bool> _copyToClipboard(ShareContent content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content.text));
      return true;
    } catch (e) {
      _logger.e('Clipboard copy failed: $e');
      return false;
    }
  }

  // Content generation methods

  ShareContent _generateGameShareContent(GameShareData gameData) {
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

  ShareContent _generatePuzzleShareContent(PuzzleShareData puzzleData) {
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

  ShareContent _generateProfileShareContent(ProfileShareData profileData) {
    final winRate = profileData.totalGamesPlayed > 0
        ? (profileData.winCount / profileData.totalGamesPlayed * 100).toStringAsFixed(1)
        : '0.0';

    final text = '''
🎓 碁縁でのプログレス報告

👤 ${profileData.displayName}
🎮 対局数: ${profileData.totalGamesPlayed}
🏆 勝利数: ${profileData.winCount} (勝率: $winRate%)
💯 詰碁: ${profileData.totalPuzzlesSolved}問
🔥 連続成功: ${profileData.currentPuzzleStreak}問

AI解説で碁を上達しよう！
#碁 #碁縁 #Go学習
'''.trim();

    return ShareContent(
      text: text,
      hashtags: '#碁 #碁縁 #Go学習',
      deepLink: 'goen://profile/${profileData.userId}',
    );
  }

  // Helper methods

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

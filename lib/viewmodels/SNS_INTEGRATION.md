# Phase 133: SNS Integration Guide

## Overview

GoEn (碁縁) includes comprehensive social media integration allowing users to share game results, puzzle achievements, and progress to X/Twitter, Facebook, WhatsApp, LINE, and clipboard.

## Architecture

### Services Layer
**`SocialShareService`** - Core service handling all sharing logic

```dart
import 'package:komovia_go/services/index.dart';

final shareService = SocialShareService();

// Share game result
await shareService.shareGameToTwitter(gameData);

// Share puzzle achievement
await shareService.sharePuzzleToTwitter(puzzleData);

// Share profile/progress
await shareService.shareProfileToTwitter(profileData);

// Generic sharing with platform selection
await shareService.shareWithPlatform(
  content,
  platform: SocialPlatform.twitter,
);
```

### Models

#### GameShareData
Represents a completed Go game for sharing

```dart
final gameData = GameShareData(
  gameId: 'game_123',
  result: 'win',              // 'win', 'loss', 'draw'
  blackScore: 45.5,
  whiteScore: 42.0,
  boardSize: 19,              // 9, 13, 19
  aiLevel: 5,                 // 1-10
  includeImage: false,
  sgfUrl: null,
);
```

#### PuzzleShareData
Represents a puzzle achievement for sharing

```dart
final puzzleData = PuzzleShareData(
  puzzleId: 'puzzle_123',
  difficulty: 'hard',         // 'easy', 'medium', 'hard', 'master'
  attemptCount: 3,
  solvingTime: Duration(minutes: 5, seconds: 30),
  isSolved: true,
  currentStreak: 7,
);
```

#### ProfileShareData
Represents user profile and progress for sharing

```dart
final profileData = ProfileShareData(
  userId: 'user_001',
  displayName: '碁の達人',
  totalGamesPlayed: 50,
  winCount: 35,
  currentPuzzleStreak: 12,
  totalPuzzlesSolved: 125,
  profileImageUrl: null,
);
```

#### ShareContent
Generated share content with text, hashtags, and metadata

```dart
final content = ShareContent(
  text: 'Game victory message',
  hashtags: '#碁 #Go #碁縁',
  imageUrl: null,
  deepLink: 'goen://game/123',
  appName: 'GoEn',
);
```

### Riverpod Providers

#### SocialShareService Provider
```dart
// Get the service instance
final service = ref.watch(socialShareServiceProvider);
```

#### Share to Twitter Provider
```dart
// Share game to Twitter
final success = await ref.read(
  shareGameToTwitterProvider(gameData: gameData).future,
);

// Share puzzle to Twitter
final success = await ref.read(
  sharePuzzleToTwitterProvider(puzzleData: puzzleData).future,
);

// Share profile to Twitter
final success = await ref.read(
  shareProfileToTwitterProvider(profileData: profileData).future,
);
```

#### Generic Platform Share Provider
```dart
final success = await ref.read(
  shareWithPlatformProvider(
    content: content,
    platform: SocialPlatform.twitter,
  ).future,
);
```

#### Share UI State Provider
```dart
// Access UI state
final uiState = ref.watch(shareUIProvider);

// Update UI state
ref.read(shareUIProvider.notifier).openShareDialog();
ref.read(shareUIProvider.notifier).closeShareDialog();
ref.read(shareUIProvider.notifier).setLoading(true);
ref.read(shareUIProvider.notifier).setError('Error message');
```

## UI Components

### GameShareButton
Share game results with a single tap

```dart
GameShareButton(
  gameData: gameData,
  onShared: () {
    print('Game shared successfully');
  },
)
```

**Features:**
- Amber FAB with share icon
- Automatic content generation
- Platform selection dialog
- Success/error feedback

### PuzzleShareButton
Share puzzle achievements

```dart
PuzzleShareButton(
  puzzleData: puzzleData,
  onShared: () {
    print('Puzzle shared successfully');
  },
)
```

**Features:**
- Cyan FAB with share icon
- Difficulty-specific formatting
- Attempt/streak tracking
- Platform selection dialog

### ShareDialog
Modal bottom sheet for platform selection

```dart
showModalBottomSheet(
  context: context,
  builder: (context) => ShareDialog(
    content: shareContent,
    onShare: (platform) {
      // Handle platform selection
    },
  ),
)
```

**Platforms:**
- X/Twitter
- Facebook
- WhatsApp
- LINE
- Copy to Clipboard

## Usage Examples

### Share Game Result in GameResultScreen

```dart
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/widgets/index.dart';

@override
Widget build(BuildContext context, WidgetRef ref) {
  final gameResult = ref.watch(gameResultProvider);

  return Scaffold(
    floatingActionButton: gameResult.when(
      data: (result) => GameShareButton(
        gameData: GameShareData(
          gameId: result.gameId,
          result: result.winner == 'black' ? 'win' : 'loss',
          blackScore: result.blackScore,
          whiteScore: result.whiteScore,
          boardSize: result.boardSize,
          aiLevel: result.aiLevel,
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    ),
    // ... rest of screen
  );
}
```

### Share Puzzle Achievement in TsumeGoScreen

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final puzzle = ref.watch(currentPuzzleProvider);

  return Scaffold(
    floatingActionButton: puzzle.when(
      data: (problem) => PuzzleShareButton(
        puzzleData: PuzzleShareData(
          puzzleId: problem.id,
          difficulty: problem.difficulty,
          attemptCount: attemptCount,
          solvingTime: solvingTime,
          isSolved: isSolved,
          currentStreak: currentStreak,
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    ),
    // ... rest of screen
  );
}
```

### Share Profile via Context Menu

```dart
showModalBottomSheet(
  context: context,
  builder: (_) => ShareDialog(
    content: _generateProfileShareContent(userProfile),
    onShare: (platform) async {
      final success = await ref.read(
        shareWithPlatformProvider(
          content: _generateProfileShareContent(userProfile),
          platform: platform,
        ).future,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${platform.displayName}で共有しました')),
        );
      }
    },
  ),
)
```

## Supported Platforms

### X/Twitter
- Uses Twitter web intent API
- Automatic hashtag inclusion
- Deep link to specific game/puzzle
- Fallback to web version if app unavailable

### Facebook
- Uses fb:// deep link scheme
- Requires app ID configuration
- Redirects to Facebook app when available

### WhatsApp
- Direct message sharing
- Uses whatsapp:// URI scheme
- Automatically opens chat selection

### LINE
- Message sharing via LINE app
- Uses line://msg/ URI scheme
- Japanese-optimized formatting

### Clipboard
- Copy share content to device clipboard
- Fallback option for all platforms
- Simple text format

## Content Generation

### Game Share Format
```
🎉 今碁で勝利しました！

🎴 19路盤
🤖 AI レベル: 5
⚫ 黒: 45.5目
⚪ 白: 42.0目

#碁 #Go #碁縁 #AI碁 #オンライン碁
```

### Puzzle Share Format
```
✨ 詰碁に成功しました！

🔴 難易度: 上級
🎯 試行回数: 3回
⏱️ 解答時間: 5分30秒
🔥 連続成功: 7問

#詰碁 #碁 #碁縁 #AI解説
```

### Profile Share Format
```
🎓 碁縁でのプログレス報告

👤 ユーザー名
🎮 対局数: 50
🏆 勝利数: 35 (勝率: 70.0%)
💯 詰碁: 125問
🔥 連続成功: 12問

AI解説で碁を上達しよう！
#碁 #碁縁 #Go学習
```

## Error Handling

```dart
Future<void> shareWithErrorHandling(
  BuildContext context,
  WidgetRef ref,
  SocialPlatform platform,
) async {
  try {
    ref.read(shareUIProvider.notifier).setLoading(true);
    
    final success = await ref.read(
      shareWithPlatformProvider(
        content: content,
        platform: platform,
      ).future,
    );

    ref.read(shareUIProvider.notifier).setLoading(false);

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${platform.displayName}で共有しました')),
        );
      }
    } else {
      ref.read(shareUIProvider.notifier)
          .setError('共有に失敗しました');
    }
  } catch (e) {
    ref.read(shareUIProvider.notifier)
        .setError('エラー: $e');
  }
}
```

## Analytics Integration

Track share events for user engagement metrics:

```dart
analytics.logEvent(
  name: 'game_shared',
  parameters: {
    'platform': 'twitter',
    'result': 'win',
    'board_size': 19,
    'ai_level': 5,
  },
);

analytics.logEvent(
  name: 'puzzle_shared',
  parameters: {
    'platform': 'line',
    'difficulty': 'hard',
    'solved': true,
  },
);

analytics.logEvent(
  name: 'profile_shared',
  parameters: {
    'platform': 'whatsapp',
    'total_games': 50,
    'win_rate': 70.0,
  },
);
```

## Testing

### Unit Tests
```bash
flutter test test/services/social_share_service_test.dart
```

### Widget Tests
```bash
flutter test test/widgets/share_button_test.dart
flutter test test/widgets/share_dialog_test.dart
```

### Integration Testing
Test on actual devices with platform-specific apps installed:
- X/Twitter mobile app
- Facebook mobile app
- WhatsApp
- LINE

## Best Practices

1. **Always provide fallback options** - Not all users have every app installed
2. **Use meaningful hashtags** - Help discovery with relevant #碁 #Go tags
3. **Include deep links** - Link back to specific games/puzzles for re-engagement
4. **Respect user privacy** - Don't auto-share sensitive game data
5. **Provide success feedback** - Show clear confirmation messages
6. **Handle errors gracefully** - Offer alternative sharing methods

## Future Enhancements

- [ ] Image sharing (board screenshots with game results)
- [ ] Video sharing (game replay animations)
- [ ] Scheduled sharing (share later feature)
- [ ] Share statistics (aggregate player stats)
- [ ] Referral tracking (utm parameters in deep links)
- [ ] Social network analysis (friend challenges)
- [ ] Multi-language support for non-Japanese locales

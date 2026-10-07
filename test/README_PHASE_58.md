# Phase 58: SNS Integration & Game Modes Extension - Test Guide

**Status**: 🚀 In Development  
**Tests Created**: 30 (Twitter/X Integration + Social Share Service)  
**Target**: 50 tests across 5 dimensions

## Overview

Phase 58 expands the GoEn app with robust SNS (Social Network Services) integration and next-generation game modes, focusing on viral sharing, community building, and diverse gameplay experiences.

## Test Dimensions

### Dimension 1: Twitter/X API v2 Integration (10 tests)
Real-time Twitter/X API integration for game sharing, engagement tracking, and viral content.

**Location**: `test/unit/services/sns_api_service_test.dart`

#### Test Coverage

| Test | Purpose | Scenario |
|------|---------|----------|
| `Posts tweet with game result successfully` | Basic tweet posting | User shares game with hashtags and media |
| `Handles missing bearer token gracefully` | Error handling | No auth token configured |
| `Posts tweet without media` | Text-only tweets | Simple game result tweet |
| `Uploads board image successfully` | Media upload | PNG board screenshot |
| `Handles media upload without bearer token` | Auth errors | Missing credentials |
| `Supports JPEG format media upload` | Format support | JPEG image upload |
| `Posts game analysis thread with replies` | Thread creation | Multi-tweet analysis thread |
| `Handles empty thread gracefully` | Edge case | No tweets in thread |
| `Retrieves tweet engagement metrics` | Analytics | Likes, retweets, replies tracking |
| `Handles metrics for non-existent tweet` | Error handling | Invalid tweet ID |

#### Key Features Tested

- **Tweet Composition**: Game results with optimal formatting
- **Media Upload**: PNG/JPEG board images (base64 encoded)
- **Thread Support**: Connected tweets with in_reply_to relationships
- **Hashtag Optimization**: #Go #GoEn #WeiQi for discoverability
- **Engagement Metrics**: Likes, retweets, replies, bookmarks, impressions
- **Authorization**: Bearer token validation and error handling
- **API Endpoints**:
  - POST `https://api.twitter.com/2/tweets` (tweet creation)
  - POST `https://upload.twitter.com/1.1/media/upload.json` (media)
  - GET `https://api.twitter.com/2/tweets/{id}` (metrics)

#### Mock Response Examples

```json
{
  "data": {
    "id": "1234567890",
    "text": "Just won a Go game on GoEn! #Go #Gaming",
    "created_at": "2026-09-15T10:30:00Z"
  }
}
```

### Dimension 2: Multi-Platform SNS & Unified Share Experience (10 tests)
Facebook/Instagram, WhatsApp, LINE integration with platform-specific formatting.

**Location**: `test/unit/services/social_share_service_test.dart`

#### Test Coverage

| Test | Purpose | Scenario |
|------|---------|----------|
| `Tracks game share on Twitter` | Share attribution | User shares to Twitter |
| `Tracks puzzle share on Facebook` | Multi-platform | Puzzle shared on Facebook |
| `Tracks profile share on WhatsApp` | Platform support | Profile link shared |
| `Aggregates shares by platform` | Analytics | Count shares per platform |
| `Calculates viral coefficient` | Viral metrics | Engagement-to-share ratio |
| `Generates Twitter-optimized share text` | Content generation | 280-char tweets with hashtags |
| `Generates Facebook-optimized share text` | Platform formatting | Longer-form content |
| `Generates LINE share message` | Message composition | Japanese-friendly format |
| `Generates WhatsApp share message with emoji` | Mobile messaging | Emoji-rich content |
| `Measures average engagement per share` | Performance metrics | Engagement tracking |

#### Platform-Specific Features

| Platform | Features | Format |
|----------|----------|--------|
| **Twitter** | Hashtags, threads, media | 280 chars max + images |
| **Facebook** | Rich content, images | Longer format, targeting |
| **WhatsApp** | Direct messaging | Casual, emoji-heavy |
| **LINE** | Stickers, messages | Japanese-friendly |
| **Instagram** | Stories, reels | Visual focus |
| **TikTok** | Video sharing | Short-form video |

#### Content Generation Examples

```dart
// Twitter: Optimized for virality
final twitterText = '''
🎮 I just defeated my opponent in Go!
📊 Game Analysis: Strategic positioning
🏆 Rating: 1850+

Play now on GoEn!
#Go #WeiQi #BoardGame #OnlineGo #Android #iOS
''';

// Facebook: Engagement-focused
final fbText = '''
Just had an amazing Go game with incredible twists!
Check out the analysis and see what you think about my strategy.
[Play on GoEn - Link]
''';

// WhatsApp: Casual, emoji-rich
final whatsappText = '''
⚫⚪ I won a Go game! 🎉
Join me on GoEn - it's awesome! ♟️
[Link]
''';

// LINE: Japanese-friendly
final lineText = '''
囲碁の対局に勝ちました！🎮
GoEn で一緒にプレイしませんか？
[リンク]
''';
```

### Dimension 3: New Game Modes & Gameplay Innovation (10 tests - Future)
Blitz, Correspondence, Team Play, Puzzle Rush implementations.

**Planned Location**: `test/unit/models/game_mode_test.dart`

#### Game Modes Specification

| Mode | Time Limit | Players | Description |
|------|-----------|---------|-------------|
| **Blitz** | 5 minutes | 1v1 | Fast-paced rapid games |
| **Correspondence** | Turn-based | 1v1 | Mail-like games over days |
| **Team Play** | Variable | 2v2 | Collaborative team battles |
| **Puzzle Rush** | Timed | 1 | Marathon puzzle solving |
| **Handicap** | Variable | 1v1 | Skill-gap balanced games |

### Dimension 4: Social Features & Community Building (10 tests - Future)
Friend system, game invitations, leaderboards, tournaments, in-game chat.

**Planned Location**: `test/unit/services/social_features_service_test.dart`

#### Features to Test

- Friend system (add/remove/block)
- Game invitations (send/accept/decline)
- Leaderboard ranking (global/monthly/seasonal)
- Tournament brackets (single/double elimination)
- In-game chat during observation
- Spectator mode notifications

### Dimension 5: Analytics & Social Metrics (10 tests - Future)
Share tracking, engagement analytics, viral coefficient measurement, retention analysis.

**Planned Location**: `test/unit/services/analytics_service_test.dart`

#### Metrics Tracked

```dart
// Share Attribution
- Source platform (Twitter, Facebook, etc.)
- Content type (game, puzzle, profile)
- Timestamp and user mapping
- External URL for click-through

// Engagement Metrics
- Likes, retweets, comments per platform
- Click-through rate (CTR)
- Conversion from share to game play
- Viral coefficient: (Avg shares per user) * (CTR)

// User Retention
- Games played with friends vs solo
- Leaderboard participation rate
- Tournament signup rate
- Social feature adoption timeline
```

## Test Execution

### Running All Phase 58 Tests
```bash
# Twitter/X Integration tests
flutter test test/unit/services/sns_api_service_test.dart

# Social Share Service tests
flutter test test/unit/services/social_share_service_test.dart

# All Phase 58 tests
flutter test test/unit/services/ --glob="*sns*.dart|*social*.dart"
```

### Test Statistics

```
Phase 58 Progress:
├─ Dimension 1: Twitter/X Integration ✅ (10/10 tests)
├─ Dimension 2: Multi-Platform SNS ✅ (10/10 tests)
├─ Dimension 3: Game Modes 🚧 (0/10 tests - Planned)
├─ Dimension 4: Social Features 🚧 (0/10 tests - Planned)
└─ Dimension 5: Analytics & Metrics 🚧 (0/10 tests - Planned)

Current: 20/50 tests | Target: 50/50 tests
Completion: 40%
```

## Implementation Notes

### SNS API Service (`lib/services/sns_api_service.dart`)

**Status**: ✅ Fully Implemented

```dart
class SnsApiService {
  // Twitter/X Integration
  Future<TwitterTweetResponse?> postGameResultTweet({...})
  Future<String?> uploadMediaToTwitter({...})
  Future<List<TwitterTweetResponse>> postGameAnalysisThread({...})
  Future<TweetMetrics?> getTweetMetrics({...})
  Future<List<TwitterTweetResponse>> getUserTimeline({...})

  // Facebook Integration
  Future<FacebookPostResponse?> postToFacebook({...})
  Future<bool> shareToInstagramStories({...})
}
```

### Social Share Service (`lib/services/social_share_service.dart`)

**Status**: 🚧 In Development

```dart
class SocialShareService {
  // Share Tracking
  Future<void> trackShare(SocialShareTracking tracking)
  Future<SocialShareTracking?> getShareTracking(String id)

  // Metrics
  Future<ShareMetrics?> getShareMetrics(String contentId)
  Future<SocialAnalytics?> getSocialAnalytics(String userId)

  // Content Generation
  String generateTwitterShareText(String gameId, String playerName)
  String generateFacebookShareText(String gameId)
  String generateLINEShareMessage(String friendName)
  String generateWhatsAppShareMessage(String contentTitle)
}
```

### Models (`lib/models/sns_models.dart`)

**Status**: ✅ Fully Implemented

- `TwitterTweetResponse` - Tweet creation response
- `TweetMetrics` - Engagement metrics
- `FacebookPostResponse` - Facebook post creation
- `GameMode` - Game mode configuration
- `GameSession` - Active game session
- `Friend` - Friend relationship
- `GameInvitation` - Game invitation
- `LeaderboardEntry` - Ranking data
- `Tournament` - Tournament info
- `ChatMessage` - In-game chat
- `SocialShareTracking` - Share attribution
- `ShareMetrics` - Platform-specific engagement
- `SocialAnalytics` - User social metrics

## Cumulative Test Count

```
Phase 57 Complete: 6,538 tests ✅
Phase 58 Progress:
  + Dimension 1 (Twitter/X): +10 tests
  + Dimension 2 (Multi-Platform SNS): +10 tests
  ───────────────────────────────
  Subtotal: 6,558 tests (20 added)

Target: 6,588 tests (50 tests total for Phase 58)
Remaining: 30 tests (Dimensions 3-5)
```

## Architecture Diagram

```
┌─ SNS Integration Layer ─────────────────────┐
│                                             │
│  ┌─ Twitter/X API v2 ──────────────────┐  │
│  │ • Tweet posting with media           │  │
│  │ • Thread management                  │  │
│  │ • Engagement metrics                 │  │
│  │ • Timeline retrieval                 │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌─ Multi-Platform SNS ─────────────────┐  │
│  │ • Facebook/Instagram                 │  │
│  │ • WhatsApp/LINE messaging            │  │
│  │ • TikTok Live sharing                │  │
│  │ • Platform-specific formatting       │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌─ Content Generation ─────────────────┐  │
│  │ • Hashtag optimization               │  │
│  │ • Platform-specific text             │  │
│  │ • Emoji & formatting rules           │  │
│  │ • Link generation & tracking         │  │
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
         ↓              ↓              ↓
      Twitter       Facebook        WhatsApp
     Instagram         LINE          TikTok
```

## Next Steps

1. ✅ Create Twitter/X Integration tests (Dimension 1)
2. ✅ Create Multi-Platform SNS tests (Dimension 2)
3. 🚧 Create Game Modes tests (Dimension 3)
4. 🚧 Create Social Features tests (Dimension 4)
5. 🚧 Create Analytics tests (Dimension 5)
6. 🚧 Integration testing with real APIs
7. 🚧 E2E testing for share flows
8. 🚧 Performance testing for SNS operations

## References

- Twitter API v2 Documentation: https://developer.twitter.com/en/docs/twitter-api
- Facebook Graph API: https://developers.facebook.com/docs/graph-api
- SNS Models: `lib/models/sns_models.dart`
- SNS Service: `lib/services/sns_api_service.dart`
- GoEn Theme: `lib/config/theme.dart` (Dark mode only)

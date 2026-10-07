import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social_share_models.dart';
import 'analytics_provider.dart';
import 'game_result_share_provider.dart' show socialShareServiceProvider;

/// Provider to share a game to Twitter
final shareGameToTwitterProvider =
    Provider<Future<bool> Function({required GameShareData gameData})>((ref) {
  final service = ref.watch(socialShareServiceProvider);
  final analytics = ref.watch(analyticsProvider);

  return ({required gameData}) async {
    final success = await service.shareGameToTwitter(gameData);

    if (success) {
      analytics.logEvent(
        name: 'game_shared',
        parameters: {
          'platform': 'twitter',
          'result': gameData.result,
          'board_size': gameData.boardSize,
          'ai_level': gameData.aiLevel,
        },
      );
    }

    return success;
  };
});

/// Provider to share a puzzle achievement to Twitter
final sharePuzzleToTwitterProvider =
    Provider<Future<bool> Function({required PuzzleShareData puzzleData})>((ref) {
  final service = ref.watch(socialShareServiceProvider);
  final analytics = ref.watch(analyticsProvider);

  return ({required puzzleData}) async {
    final success = await service.sharePuzzleToTwitter(puzzleData);

    if (success) {
      analytics.logEvent(
        name: 'puzzle_shared',
        parameters: {
          'platform': 'twitter',
          'difficulty': puzzleData.difficulty,
          'solved': puzzleData.isSolved,
          'attempts': puzzleData.attemptCount,
        },
      );
    }

    return success;
  };
});

/// Provider to share profile to Twitter
final shareProfileToTwitterProvider =
    Provider<Future<bool> Function({required ProfileShareData profileData})>((ref) {
  final service = ref.watch(socialShareServiceProvider);
  final analytics = ref.watch(analyticsProvider);

  return ({required profileData}) async {
    final success = await service.shareProfileToTwitter(profileData);

    if (success) {
      final winRate = profileData.totalGamesPlayed > 0
          ? (profileData.winCount / profileData.totalGamesPlayed) * 100
          : 0.0;
      analytics.logEvent(
        name: 'profile_shared',
        parameters: {
          'platform': 'twitter',
          'total_games': profileData.totalGamesPlayed,
          'win_rate': winRate,
          'puzzles_solved': profileData.totalPuzzlesSolved,
        },
      );
    }

    return success;
  };
});

/// Provider to share to a specific platform.
///
/// Kept as a `FutureProvider.family` (rather than the plain-action-Provider
/// pattern used above) because `GameShareButton`/`PuzzleShareButton`
/// (views/widgets/share_button.dart) call it as
/// `ref.read(shareWithPlatformProvider(content: ..., platform: ...).future)`
/// — changing the shape here would mean updating those call sites too.
final shareWithPlatformProvider = FutureProvider.family<bool,
    ({ShareContent content, SocialPlatform platform})>((ref, params) async {
  final service = ref.watch(socialShareServiceProvider);
  final analytics = ref.watch(analyticsProvider);

  final success = await service.shareWithPlatform(params.content, platform: params.platform);

  if (success) {
    analytics.logEvent(
      name: 'content_shared_to_platform',
      parameters: {
        'platform': params.platform.toString().split('.').last,
      },
    );
  }

  return success;
});

/// Provider for generic share to system share sheet
final shareGenericProvider =
    Provider<Future<bool> Function({required ShareContent content})>((ref) {
  final service = ref.watch(socialShareServiceProvider);
  return ({required content}) => service.shareGeneric(content);
});

/// State for tracking share UI visibility
class ShareUIState {
  final bool isShareDialogOpen;
  final bool isLoading;
  final String? errorMessage;

  ShareUIState({
    this.isShareDialogOpen = false,
    this.isLoading = false,
    this.errorMessage,
  });

  ShareUIState copyWith({
    bool? isShareDialogOpen,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ShareUIState(
      isShareDialogOpen: isShareDialogOpen ?? this.isShareDialogOpen,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for share UI state
class ShareUINotifier extends StateNotifier<ShareUIState> {
  ShareUINotifier() : super(ShareUIState());

  void openShareDialog() {
    state = state.copyWith(isShareDialogOpen: true);
  }

  void closeShareDialog() {
    // copyWith uses `?? this.field`, which can't distinguish "explicitly
    // null" from "not provided" - construct directly to actually clear it.
    state = ShareUIState(
      isShareDialogOpen: false,
      isLoading: state.isLoading,
      errorMessage: null,
    );
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = ShareUIState(
      isShareDialogOpen: state.isShareDialogOpen,
      isLoading: state.isLoading,
      errorMessage: error,
    );
  }
}

/// Provider for share UI state
final shareUIProvider = StateNotifierProvider<ShareUINotifier, ShareUIState>((ref) {
  return ShareUINotifier();
});

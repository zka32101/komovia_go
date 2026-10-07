// Barrel file for all providers - enables: `import 'package:komovia_go/viewmodels/index.dart';`

export 'auth_provider.dart';
export 'game_provider.dart';
export 'game_mode_provider.dart';
// game_modes_provider.dart independently declares its own
// GameModeUIState/GameModeUINotifier/gameModeUIProvider (a different shape,
// for the Blitz/Correspondence/Team/PuzzleRush mode picker) that collide
// with game_mode_provider.dart's — the ones game_mode_selector_screen.dart
// actually calls (`.selectMode`, not `.selectGameMode`). Nothing references
// game_modes_provider.dart's versions, so hide them here.
export 'game_modes_provider.dart'
    hide GameModeUIState, GameModeUINotifier, gameModeUIProvider;
export 'ad_provider.dart';
export 'game_settings_provider.dart';
export 'locale_provider.dart';
export 'tsume_go_provider.dart';
export 'kifu_go_provider.dart';
export 'analytics_provider.dart';
export 'social_share_provider.dart';
export 'streaming_provider.dart';
export 'game_result_share_provider.dart';
export 'social_features_provider.dart';
export 'game_modes_analytics_provider.dart';
export 'leaderboard_provider.dart';
// friend_provider.dart's friendServiceProvider/addFriendProvider/
// acceptFriendRequestProvider/blockFriendProvider/pendingFriendRequestsProvider/
// rejectFriendRequestProvider are unwired stubs (see friend_provider.dart)
// that collide with social_features_provider.dart's working versions of the
// same names, which is what friends_screen.dart actually calls; hide the
// stubs (pendingFriendRequestsProvider's sibling, the equally-dead
// userFriendsProvider, was removed outright rather than hidden, since
// nothing called it and social_features_provider.dart's
// acceptedFriendsProvider/friendsStreamProvider already cover the same
// job for real).
export 'friend_provider.dart'
    hide
        friendServiceProvider,
        addFriendProvider,
        acceptFriendRequestProvider,
        blockFriendProvider,
        pendingFriendRequestsProvider,
        rejectFriendRequestProvider;
export 'tournament_provider.dart';
export 'notification_provider.dart';
export 'spectator_provider.dart';
export 'matching_provider.dart';
export 'playstyle_provider.dart';
export 'position_echo_provider.dart';
export 'friend_activity_provider.dart';
export 'fateful_move_provider.dart';
export 'concurrent_session_provider.dart';
export 'en_score_provider.dart';
export 'pvp_game_provider.dart';
export 'ai_review_provider.dart';
export 'purchase_provider.dart';
export 'direct_message_provider.dart';

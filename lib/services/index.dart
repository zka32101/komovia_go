// Barrel file for all services - enables: `import 'package:komovia_go/services/index.dart';`

// go_engine_service.dart is the legacy Cloud Functions engine, kept only
// for reference; AIMove/GameEndResult are hidden here so the actively used
// Fuego (on-device) versions from fuego_engine_service.dart are the ones
// resolved by `import 'package:komovia_go/services/index.dart'`.
export 'go_engine_service.dart' hide AIMove, GameEndResult;
export 'fuego_engine_service.dart';
export 'go_rules.dart';
export 'go_scoring.dart';
export 'firestore_service.dart';
export 'auth_service.dart';
export 'ai_explanation_service.dart';
export 'social_share_service.dart';
export 'sns_api_service.dart';
export 'game_mode_service.dart';
export 'youtube_share_service.dart';
export 'twitch_share_service.dart';
export 'sponsorship_service.dart';
export 'blitz_game_service.dart';
export 'ad_service.dart';
export 'correspondence_game_service.dart';
export 'team_game_service.dart';
export 'puzzle_rush_service.dart';
export 'game_settings_storage_service.dart';
export 'friend_service.dart';
export 'game_invitation_service.dart';
export 'leaderboard_service.dart';
export 'tournament_service.dart';
export 'game_preset_service.dart';
export 'analytics_service.dart';
export 'notification_service.dart';
export 'push_notification_service.dart';
export 'spectator_service.dart';
export 'matching_service.dart';
export 'playstyle_service.dart';
export 'position_echo_service.dart';
export 'friend_activity_service.dart';
export 'fateful_move_service.dart';
export 'concurrent_session_service.dart';
export 'en_score_service.dart';
export 'pvp_game_service.dart';
export 'purchase_service.dart';

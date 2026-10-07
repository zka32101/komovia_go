// Barrel file for all models - enables: `import 'package:komovia_go/models/index.dart';`

export 'user.dart';
export 'game_record.dart';
export 'ai_opponent_config.dart';
export 'tsume_go_problem.dart';
export 'user_tsume_go_log.dart';
export 'kifu_library.dart';
export 'observation_log.dart';
export 'board_state.dart';
export 'social_share_models.dart';
// sns_models.dart duplicates several names declared elsewhere in this
// barrel (Friend, LeaderboardEntry, Tournament, GameInvitation) with a
// different shape; hide those so the actively-used dedicated model files
// stay the canonical ones. GameModeType is the reverse case: this is the
// version actually wired to game_mode_service.dart / game_mode_provider.dart,
// so it's hidden from game_modes.dart below instead.
// freezed also generates a public `$XCopyWith` mixin and an `XPatterns`
// extension per class (not just the class name itself), so each hidden
// class's CopyWith/Patterns must be hidden alongside it or the barrel
// export is ambiguous.
export 'sns_models.dart'
    hide
        Friend,
        LeaderboardEntry,
        Tournament,
        GameInvitation,
        $FriendCopyWith,
        $LeaderboardEntryCopyWith,
        $TournamentCopyWith,
        $GameInvitationCopyWith,
        FriendPatterns,
        LeaderboardEntryPatterns,
        TournamentPatterns,
        GameInvitationPatterns;
export 'streaming_models.dart';
export 'game_modes.dart' hide GameModeType;
export 'game_settings.dart';
// extended_game_models.dart predates the dedicated game_record.dart and
// leaderboard.dart models and declares its own GameRecord/LeaderboardEntry
// with a different (Firestore-incompatible) shape; hide those two so the
// dedicated models win. Its Friend/GameInvitation are the ones actually
// wired to FriendService/GameInvitationService, so those stay exported.
export 'extended_game_models.dart'
    hide
        GameRecord,
        LeaderboardEntry,
        $GameRecordCopyWith,
        $LeaderboardEntryCopyWith,
        GameRecordPatterns,
        LeaderboardEntryPatterns;
export 'leaderboard.dart';
// friend.dart's Friend (uid/friendUid/addedAt/isBlocked) isn't wired to any
// working service (see friend_provider.dart) and collides with
// extended_game_models.dart's Friend, which is what FriendService and
// friends_screen.dart actually use; hide it and keep FriendRequest.
export 'friend.dart' hide Friend;
export 'tournament.dart';
export 'notification.dart';
export 'spectator.dart';
export 'matching.dart';
export 'playstyle.dart';
export 'position_echo.dart';
export 'friend_activity.dart';
export 'fateful_move.dart';
export 'concurrent_session.dart';
export 'en_score.dart';
export 'pvp_game.dart';
export 'direct_message.dart';

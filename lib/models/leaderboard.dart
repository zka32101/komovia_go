// `LeaderboardEntry`/`LeaderboardPeriod`/`LeaderboardType` used to be
// declared here with their own Firestore-coupled shape
// (`fromFirestore`/`toFirestore`), but that shape has been ported
// field-for-field to `package:komovia_core`'s `Friendship`-sibling model of
// the same name - re-exported here unchanged so every existing
// `import 'package:komovia_go/models/leaderboard.dart';` keeps working.
//
// Firestore conversion (`Timestamp`<->`DateTime`) now lives in
// `services/leaderboard_service.dart` as a private adapter, the same way
// komovia_core's other extracted models (`Friendship`, `AppNotification`,
// ...) keep storage out of the shared model and into each app's own
// service layer.
//
// `getDisplayName()` on the two enums (a Japanese display label, used only
// by `LeaderboardScreen`) has no komovia_core equivalent - kept as local
// extensions in `leaderboard_display.dart` instead of being dropped.
export 'package:komovia_core/komovia_core.dart'
    show LeaderboardEntry, LeaderboardPeriod, LeaderboardType;
export 'leaderboard_display.dart';

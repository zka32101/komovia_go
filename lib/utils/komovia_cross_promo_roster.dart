import 'package:komovia_core/komovia_core.dart';

/// This app's own id, matching the `appId` this app would use if it
/// were listed in [komoviaRoster] from a sibling app's point of view.
const String kKomoviaGoAppId = 'komovia_go';

/// The known Komovia family apps, for cross-promotion
/// ([otherKomoviaApps] excludes [kKomoviaGoAppId] when this app renders
/// the list). Hardcoded rather than fetched since this is a closed
/// family of 3 apps maintained by the same developer, not an open-ended
/// portfolio - mirrors komovia_chess's `komovia_cross_promo_roster.dart`.
///
/// NOTE: the store URLs below are placeholders - none of these 3 apps
/// has a confirmed, real App Store/Play Store listing yet. Fill these
/// in with the real URLs once each app actually ships; until then the
/// settings screen shows the card but disables the tap target rather
/// than opening a broken link.
const List<PromotedApp> komoviaRoster = [
  PromotedApp(
    appId: 'komovia_chess',
    name: 'Komoviaチェス',
    tagline: 'AI対局・タクティクスパズル',
    category: 'chess',
    iconPath: 'assets/icons/chess.png',
  ),
  PromotedApp(
    appId: 'komovia_shogi',
    name: 'Komovia将棋',
    tagline: 'AI対局・詰将棋',
    category: 'shogi',
    iconPath: 'assets/icons/shogi.png',
  ),
  PromotedApp(
    appId: kKomoviaGoAppId,
    name: 'Komovia囲碁',
    tagline: 'AI対局・詰碁',
    category: 'go',
    iconPath: 'assets/icons/go.png',
  ),
];

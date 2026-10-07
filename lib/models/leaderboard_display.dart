import 'package:komovia_core/komovia_core.dart';

/// Japanese display labels for [LeaderboardPeriod]/[LeaderboardType] -
/// `LeaderboardScreen`'s own UI concern, with no equivalent on
/// komovia_core's game-agnostic enums (which only know `toShortString`/
/// `fromString`, used for Firestore path segments).
extension LeaderboardPeriodDisplay on LeaderboardPeriod {
  String getDisplayName() {
    switch (this) {
      case LeaderboardPeriod.daily:
        return '日次';
      case LeaderboardPeriod.weekly:
        return '週間';
      case LeaderboardPeriod.monthly:
        return '月間';
      case LeaderboardPeriod.allTime:
        return '通算';
    }
  }
}

extension LeaderboardTypeDisplay on LeaderboardType {
  String getDisplayName() {
    switch (this) {
      case LeaderboardType.rating:
        return 'レーティング';
      case LeaderboardType.puzzles:
        return '詰碁';
      case LeaderboardType.achievements:
        return '実績';
      case LeaderboardType.tournament:
        return 'トーナメント';
    }
  }
}

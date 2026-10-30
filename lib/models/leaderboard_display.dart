import 'package:komovia_core/komovia_core.dart';

/// Japanese display labels for [LeaderboardPeriod]/[LeaderboardType] -
/// `LeaderboardScreen`'s own UI concern, with no equivalent on
/// komovia_core's game-agnostic enums (which only know `toShortString`/
/// `fromString`, used for Firestore path segments).
extension LeaderboardPeriodDisplay on LeaderboardPeriod {
  String getDisplayName({bool ja = true}) {
    switch (this) {
      case LeaderboardPeriod.daily:
        return ja ? '日次' : 'Daily';
      case LeaderboardPeriod.weekly:
        return ja ? '週間' : 'Weekly';
      case LeaderboardPeriod.monthly:
        return ja ? '月間' : 'Monthly';
      case LeaderboardPeriod.allTime:
        return ja ? '通算' : 'All time';
    }
  }
}

extension LeaderboardTypeDisplay on LeaderboardType {
  String getDisplayName({bool ja = true}) {
    switch (this) {
      case LeaderboardType.rating:
        return ja ? 'レーティング' : 'Rating';
      case LeaderboardType.puzzles:
        return ja ? '詰碁' : 'Tsume-go';
      case LeaderboardType.achievements:
        return ja ? '実績' : 'Achievements';
      case LeaderboardType.tournament:
        return ja ? 'トーナメント' : 'Tournament';
    }
  }
}

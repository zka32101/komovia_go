import 'package:cloud_firestore/cloud_firestore.dart';

/// ランキング エントリ（ユーザーの順位スコア）
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int rank;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final double winRate;
  final int puzzlesSolved;
  final int achievementsUnlocked;
  final int tournamentWins;
  final DateTime lastUpdated;

  LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.rank,
    required this.rating,
    required this.gamesPlayed,
    required this.wins,
    required this.winRate,
    required this.puzzlesSolved,
    this.achievementsUnlocked = 0,
    this.tournamentWins = 0,
    required this.lastUpdated,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return LeaderboardEntry(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Anonymous',
      rank: data['rank'] ?? 0,
      rating: data['rating'] ?? 1200,
      gamesPlayed: data['gamesPlayed'] ?? 0,
      wins: data['wins'] ?? 0,
      winRate: (data['winRate'] ?? 0.0).toDouble(),
      puzzlesSolved: data['puzzlesSolved'] ?? 0,
      achievementsUnlocked: data['achievementsUnlocked'] ?? 0,
      tournamentWins: data['tournamentWins'] ?? 0,
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'rank': rank,
      'rating': rating,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'winRate': winRate,
      'puzzlesSolved': puzzlesSolved,
      'achievementsUnlocked': achievementsUnlocked,
      'tournamentWins': tournamentWins,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  LeaderboardEntry copyWith({
    String? uid,
    String? displayName,
    int? rank,
    int? rating,
    int? gamesPlayed,
    int? wins,
    double? winRate,
    int? puzzlesSolved,
    int? achievementsUnlocked,
    int? tournamentWins,
    DateTime? lastUpdated,
  }) {
    return LeaderboardEntry(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      rank: rank ?? this.rank,
      rating: rating ?? this.rating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      winRate: winRate ?? this.winRate,
      puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
      achievementsUnlocked: achievementsUnlocked ?? this.achievementsUnlocked,
      tournamentWins: tournamentWins ?? this.tournamentWins,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, displayName: $displayName, rating: $rating)';
}

/// ランキング期間（週間、月間、通算など）
enum LeaderboardPeriod {
  daily,      // 日次
  weekly,     // 週間
  monthly,    // 月間
  allTime;    // 通算

  String toShortString() {
    switch (this) {
      case LeaderboardPeriod.daily:
        return 'daily';
      case LeaderboardPeriod.weekly:
        return 'weekly';
      case LeaderboardPeriod.monthly:
        return 'monthly';
      case LeaderboardPeriod.allTime:
        return 'all_time';
    }
  }

  static LeaderboardPeriod fromString(String value) {
    switch (value) {
      case 'daily':
        return LeaderboardPeriod.daily;
      case 'weekly':
        return LeaderboardPeriod.weekly;
      case 'monthly':
        return LeaderboardPeriod.monthly;
      case 'all_time':
        return LeaderboardPeriod.allTime;
      default:
        return LeaderboardPeriod.allTime;
    }
  }

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

/// ランキング タイプ（対戦, 詰碁など）
enum LeaderboardType {
  rating,         // ELO Rating (AI games)
  puzzles,        // Puzzle solving count
  achievements,   // Achievements/badges
  tournament;     // Tournament rank

  String toShortString() {
    switch (this) {
      case LeaderboardType.rating:
        return 'rating';
      case LeaderboardType.puzzles:
        return 'puzzles';
      case LeaderboardType.achievements:
        return 'achievements';
      case LeaderboardType.tournament:
        return 'tournament';
    }
  }

  static LeaderboardType fromString(String value) {
    switch (value) {
      case 'rating':
        return LeaderboardType.rating;
      case 'puzzles':
        return LeaderboardType.puzzles;
      case 'achievements':
        return LeaderboardType.achievements;
      case 'tournament':
        return LeaderboardType.tournament;
      default:
        return LeaderboardType.rating;
    }
  }

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

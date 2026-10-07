import 'package:cloud_firestore/cloud_firestore.dart';

/// Game record (kifu) for observation and study with AI commentary
class KifuLibrary {
  final String id;
  final String title;
  final String? blackPlayer;
  final String? whitePlayer;
  final String sgfData; // Original game in SGF format
  final String? aiCommentaryData; // AI explanation data (JSON or structured)
  final KifuCategory category;
  final bool isPremium; // Premium-only content
  final String source; // Attribution (copyright-free historical games)
  final DateTime? gameDate;
  final DateTime createdAt;
  // 1-5: 1=easy, 5=very hard. Nullable since curated entries aren't all
  // rated yet (unlike TsumeGoProblem.difficulty, which is required).
  final int? difficulty;

  KifuLibrary({
    required this.id,
    required this.title,
    this.blackPlayer,
    this.whitePlayer,
    required this.sgfData,
    this.aiCommentaryData,
    required this.category,
    required this.isPremium,
    required this.source,
    this.gameDate,
    required this.createdAt,
    this.difficulty,
  });

  /// Create from Firestore document
  factory KifuLibrary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return KifuLibrary(
      id: doc.id,
      title: data['title'] ?? '',
      blackPlayer: data['blackPlayer'],
      whitePlayer: data['whitePlayer'],
      sgfData: data['sgfData'] ?? '',
      aiCommentaryData: data['aiCommentaryData'],
      category: KifuCategory.fromString(data['category'] ?? 'free'),
      isPremium: data['isPremium'] ?? false,
      source: data['source'] ?? '',
      gameDate: data['gameDate'] != null ? (data['gameDate'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      difficulty: (data['difficulty'] as num?)?.toInt(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'blackPlayer': blackPlayer,
      'whitePlayer': whitePlayer,
      'sgfData': sgfData,
      'aiCommentaryData': aiCommentaryData,
      'category': category.toShortString(),
      'isPremium': isPremium,
      'source': source,
      'gameDate': gameDate != null ? Timestamp.fromDate(gameDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'difficulty': difficulty,
    };
  }

  /// Human-readable difficulty name (same star convention as
  /// TsumeGoProblem.getDifficultyName), or null if unrated.
  String? getDifficultyName() {
    switch (difficulty) {
      case 1:
        return '★☆☆☆☆';
      case 2:
        return '★★☆☆☆';
      case 3:
        return '★★★☆☆';
      case 4:
        return '★★★★☆';
      case 5:
        return '★★★★★';
      default:
        return null;
    }
  }

  String getDisplayTitle() {
    if (blackPlayer != null && whitePlayer != null) {
      return '$blackPlayer vs $whitePlayer';
    }
    return title;
  }

  /// Get list of players
  List<String> get players {
    final result = <String>[];
    if (blackPlayer != null) result.add(blackPlayer!);
    if (whitePlayer != null) result.add(whitePlayer!);
    return result;
  }

  @override
  String toString() =>
      'KifuLibrary(id: $id, title: $title, category: $category, isPremium: $isPremium)';
}

/// Kifu category - free means copyright-free historical games, owned means user's own games
enum KifuCategory {
  copyrightFree, // Historical games (by-sa heritage)
  ownGames, // User's own game records
  unknown;

  String toShortString() {
    switch (this) {
      case KifuCategory.copyrightFree:
        return 'copyright_free';
      case KifuCategory.ownGames:
        return 'own_games';
      case KifuCategory.unknown:
        return 'unknown';
    }
  }

  static KifuCategory fromString(String value) {
    switch (value) {
      case 'copyright_free':
        return KifuCategory.copyrightFree;
      case 'own_games':
        return KifuCategory.ownGames;
      default:
        return KifuCategory.unknown;
    }
  }

  @override
  String toString() => toShortString();
}

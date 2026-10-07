import 'package:cloud_firestore/cloud_firestore.dart';

/// Tsume-go problem (Go puzzle)
class TsumeGoProblem {
  final String id;
  final int difficulty; // 1-5: 1=easy, 5=very hard
  final String sgfData; // Initial board setup in SGF format
  // Correct solution: a full board-snapshot in the app's own SGF dialect
  // (see BoardState.toSgf()/fromSgf()), i.e. the final position after the
  // solution is played out — not a move-by-move sequence. This is what
  // checkPuzzleSolutionProvider (tsume_go_provider.dart) compares the
  // live puzzle board against.
  final String solutionSgf;
  final String explanation; // Japanese explanation
  final String source; // Copyright-free source attribution
  final int version; // Problem set version
  final DateTime createdAt;
  final int? expectedMoves; // Hint: how many moves for solution

  TsumeGoProblem({
    required this.id,
    required this.difficulty,
    required this.sgfData,
    required this.solutionSgf,
    required this.explanation,
    required this.source,
    required this.version,
    required this.createdAt,
    this.expectedMoves,
  });

  /// Create from Firestore document
  factory TsumeGoProblem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TsumeGoProblem(
      id: doc.id,
      difficulty: data['difficulty'] ?? 1,
      sgfData: data['sgfData'] ?? '',
      solutionSgf: data['solutionSgf'] ?? '',
      explanation: data['explanation'] ?? '',
      source: data['source'] ?? '',
      version: data['version'] ?? 1,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expectedMoves: data['expectedMoves'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'difficulty': difficulty,
      'sgfData': sgfData,
      'solutionSgf': solutionSgf,
      'explanation': explanation,
      'source': source,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'expectedMoves': expectedMoves,
    };
  }

  /// Get human-readable difficulty name
  String getDifficultyName() {
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
        return '不明';
    }
  }

  @override
  String toString() =>
      'TsumeGoProblem(id: $id, difficulty: $difficulty ${getDifficultyName()}, source: $source)';
}

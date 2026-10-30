import 'go_scoring.dart';

/// Decides whether the AI opponent in an AI game should resign.
///
/// Without this, the AI has no notion of a hopeless position - it only
/// ever passes when its own Monte Carlo search judges passing better than
/// playing on (see DartGoEngine.chooseMoveSync), which it never will while
/// behind, since passing locks in a score it's already losing. Left alone,
/// a human playing a decisively winning position has to keep capturing
/// every single AI stone to end the game - under Chinese area scoring
/// (go_scoring.dart) that drags out to the literal extreme of the human
/// owning the entire board, instead of the AI resigning once the outcome
/// is no longer in doubt, the way a real opponent would.
class AiResignationService {
  AiResignationService._();

  /// Resignation is only even considered once at least this fraction of
  /// the board has been played - matches DartGoEngine's own "pass is only
  /// a real option once the opening is over" threshold, since a Chinese
  /// area-score estimate on a near-empty board is meaningless (almost the
  /// whole board is still nobody's territory).
  static const double minBoardFractionPlayed = 0.25;

  /// How far behind, as a fraction of the board's total points, the AI's
  /// current rough area-score estimate must show before a single check
  /// counts as "hopeless". Deliberately large - this is for a position
  /// that's clearly decided, not a routine ordinary deficit.
  static const double marginFraction = 0.25;

  /// Consecutive hopeless checks required (across the AI's own successive
  /// moves) before actually resigning. Guards against resigning off one
  /// sharp tactical swing - e.g. right after a capture that's about to be
  /// recaptured, which would make the raw stone-count estimate look far
  /// more one-sided than the position actually is.
  static const int consecutiveChecksRequired = 3;

  /// Returns true if, on [stones], the side the AI is playing is behind by
  /// at least [marginFraction] of the board's total points under a rough
  /// (no dead-stone removal) Chinese area-score estimate. This is
  /// deliberately a rough estimate, not real scoring - it only needs to be
  /// right about positions that are lopsided enough to resign from, where
  /// unsettled life-and-death status doesn't change the conclusion.
  static bool isHopelesslyBehind({
    required List<List<int>> stones,
    required int boardSize,
    required bool aiIsBlack,
  }) {
    final total = boardSize * boardSize;

    var stoneCount = 0;
    for (final row in stones) {
      for (final cell in row) {
        if (cell != 0) stoneCount++;
      }
    }
    if (stoneCount < total * minBoardFractionPlayed) return false;

    final score = GoScoring.computeAreaScore(stones, boardSize);
    final aiScore = aiIsBlack ? score.blackScore : score.whiteScore;
    final opponentScore = aiIsBlack ? score.whiteScore : score.blackScore;
    return (opponentScore - aiScore) >= total * marginFraction;
  }
}

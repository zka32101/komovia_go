import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/game_record.dart';
import 'package:komovia_go/utils/ai_rating.dart';

void main() {
  group('opponentRatingForAiLevel', () {
    test('level 5 maps to the 1200 baseline', () {
      expect(opponentRatingForAiLevel(5), 1200);
    });

    test('increases with level and decreases below it', () {
      expect(opponentRatingForAiLevel(10), 1950);
      expect(opponentRatingForAiLevel(1), 600);
    });

    test('clamps out-of-range levels instead of extrapolating', () {
      expect(opponentRatingForAiLevel(99), opponentRatingForAiLevel(10));
      expect(opponentRatingForAiLevel(-3), opponentRatingForAiLevel(1));
    });
  });

  group('computeRatingDelta', () {
    test('beating an equally-rated opponent gains roughly half the K-factor', () {
      final delta = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5, // opponentRating == 1200 too
        result: GameResult.playerWin,
      );
      expect(delta, 12); // K=24 * (1 - 0.5)
    });

    test('losing to an equally-rated opponent loses the same amount', () {
      final delta = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5,
        result: GameResult.aiWin,
      );
      expect(delta, -12);
    });

    test('beating a much stronger AI gains more than beating an equal one', () {
      final vsEqual = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5,
        result: GameResult.playerWin,
      );
      final vsStronger = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 10,
        result: GameResult.playerWin,
      );
      expect(vsStronger, greaterThan(vsEqual));
    });

    test('losing to a much weaker AI loses more than losing to an equal one', () {
      final vsEqual = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5,
        result: GameResult.aiWin,
      );
      final vsWeaker = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 1,
        result: GameResult.aiWin,
      );
      expect(vsWeaker, lessThan(vsEqual));
    });

    test('resignation is scored the same as an AI win', () {
      final aiWin = computeRatingDelta(
        currentRating: 1500,
        aiLevel: 7,
        result: GameResult.aiWin,
      );
      final resignation = computeRatingDelta(
        currentRating: 1500,
        aiLevel: 7,
        result: GameResult.resignation,
      );
      expect(resignation, aiWin);
    });

    test('draw nudges rating toward the opponent, not flat zero unless equal', () {
      final delta = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5,
        result: GameResult.draw,
      );
      expect(delta, 0); // equal ratings: a draw is exactly expected
    });

    test('unknown result never changes rating', () {
      final delta = computeRatingDelta(
        currentRating: 1200,
        aiLevel: 5,
        result: GameResult.unknown,
      );
      expect(delta, 0);
    });
  });
}

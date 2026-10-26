/// AI対局の結果から、プレイヤーの「AI戦レーティング」(User.aiRating)の
/// 増減を計算する。Eloレーティングの考え方を単純化したもの:
/// 自分より強い相手に勝てば大きく増え、弱い相手に負ければ大きく減る。
/// 格下相手への勝利・格上相手への敗北はほとんど変動しない。
library;

import 'dart:math' as math;

import 'package:komovia_go/models/game_record.dart';

/// AIレベル(1-10)を、formatGoRank()と同じレーティング尺度上の
/// 「相手の強さ」に変換する。レベル5を基準の1200（8級相当）とし、
/// レベル1刻みで150変動する - レベル10で約1950（初段手前）、
/// レベル1で約600（非常に弱い）になる。
int opponentRatingForAiLevel(int aiLevel) {
  final clamped = aiLevel.clamp(1, 10);
  return 1200 + (clamped - 5) * 150;
}

/// K係数。1局あたりの最大変動幅を決める。対局数が少ないうちから
/// 着実に数字が動いて「成長の実感」につながるよう、一般的なEloの
/// K=16〜32よりやや大きめの24を採用。
const int _kFactor = 24;

/// 現在のレーティング[currentRating]で、レベル[aiLevel]のAIと対局し
/// [result]という結果だった場合の、レーティング増減量を返す（符号付き）。
/// 投了(resignation)はaiWinと同じ扱い、drawは引き分け(0.5)として扱う。
/// 石を置かずに終わった`unknown`は変動なし(0)とする。
int computeRatingDelta({
  required int currentRating,
  required int aiLevel,
  required GameResult result,
}) {
  if (result == GameResult.unknown) return 0;

  final opponentRating = opponentRatingForAiLevel(aiLevel);
  final expectedScore =
      1 / (1 + math.pow(10, (opponentRating - currentRating) / 400));

  final double actualScore;
  switch (result) {
    case GameResult.playerWin:
      actualScore = 1.0;
    case GameResult.aiWin:
    case GameResult.resignation:
      actualScore = 0.0;
    case GameResult.draw:
      actualScore = 0.5;
    case GameResult.unknown:
      actualScore = 0.5; // unreachable (handled above)
  }

  return (_kFactor * (actualScore - expectedScore)).round();
}

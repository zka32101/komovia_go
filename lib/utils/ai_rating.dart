/// AI対局の結果から、プレイヤーの「AI戦レーティング」の増減を計算する。
///
/// 実際の計算式自体は、他のKomoviaアプリ(将棋・リバーシ・チェス)も同じ
/// 「成長トラッキング」機能で再利用できるよう、komovia_coreの
/// computeEloDelta/ratingForAiLevel（Eloレーティングの考え方を単純化
/// したもの）に移した。この碁アプリ用の値(K=24、レベル1-10/基準レベル5/
/// 150刻み)はこのファイルの関数のデフォルト引数として保持し、呼び出し側
/// (game_provider.dart/growth_screen.dart)が以前と同じ見た目で使えるよう
/// にしている。
library;

import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_go/models/game_record.dart';

/// AIレベル(1-10)を、formatGoRank()と同じレーティング尺度上の
/// 「相手の強さ」に変換する。レベル5を基準の1200（8級相当）とし、
/// レベル1刻みで150変動する - レベル10で約1950（初段手前）、
/// レベル1で約600（非常に弱い）になる。
int opponentRatingForAiLevel(int aiLevel) {
  return core.ratingForAiLevel(
    level: aiLevel,
    minLevel: 1,
    maxLevel: 10,
    baseLevel: 5,
  );
}

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

  return core.computeEloDelta(
    currentRating: currentRating,
    opponentRating: opponentRatingForAiLevel(aiLevel),
    score: actualScore,
  );
}

import 'package:flutter/services.dart';

/// 石を置いたときの触覚・聴覚フィードバック。
///
/// 新規パッケージ/音声アセットを追加せず、Flutter標準の
/// HapticFeedback / SystemSound だけで「置いた感」を出す
/// （このサンドボックスには dart/flutter tooling がなく、新規依存関係の
/// pub取得やアセット同梱を検証できないための制約）。
void playStonePlaceFeedback() {
  HapticFeedback.mediumImpact();
  SystemSound.play(SystemSoundType.click);
}

/// 着手が拒否された（既に石がある/自殺手/コウ）ときの軽いフィードバック。
void playIllegalMoveFeedback() {
  HapticFeedback.vibrate();
}

/// 石を取った（アゲハマが発生した）ときの、通常の着手より強めのフィードバック。
void playCaptureFeedback() {
  HapticFeedback.heavyImpact();
  SystemSound.play(SystemSoundType.click);
}

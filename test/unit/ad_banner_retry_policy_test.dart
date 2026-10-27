import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/views/widgets/ad_banner.dart';

/// AdBannerの広告読み込み失敗時リトライロジックのテスト。
///
/// 以前は`onAdFailedToLoad`がログ出力のみで何もせず、ウィジェットは
/// その後永久に`SizedBox.shrink()`を返し続けていた（一時的なネットワーク
/// 不調でも、画面を離れて戻らない限り二度と広告が出ない = その画面分の
/// 広告収益が丸ごと失われる）。`google_mobile_ads`のプラットフォーム
/// チャネルはテスト環境でモックされていないため、実際の`BannerAd.load()`
/// を駆動するウィジェットテストは書けない。再試行の間隔を決める純粋関数
/// `AdBannerRetryPolicy.delayForAttempt`を切り出し、ここで単体テストする。
void main() {
  group('AdBannerRetryPolicy.delayForAttempt', () {
    test('1回目の失敗後は5秒待つ', () {
      expect(AdBannerRetryPolicy.delayForAttempt(1), const Duration(seconds: 5));
    });

    test('2回目の失敗後は10秒（指数バックオフ）', () {
      expect(AdBannerRetryPolicy.delayForAttempt(2), const Duration(seconds: 10));
    });

    test('3回目の失敗後は20秒', () {
      expect(AdBannerRetryPolicy.delayForAttempt(3), const Duration(seconds: 20));
    });

    test('最大試行回数(3)を超えたらnullを返し、再試行しない', () {
      expect(AdBannerRetryPolicy.delayForAttempt(4), isNull);
      expect(AdBannerRetryPolicy.delayForAttempt(100), isNull);
    });

    test('0以下の試行番号は不正としてnullを返す', () {
      expect(AdBannerRetryPolicy.delayForAttempt(0), isNull);
      expect(AdBannerRetryPolicy.delayForAttempt(-1), isNull);
    });

    test('maxRetriesは3', () {
      expect(AdBannerRetryPolicy.maxRetries, 3);
    });
  });
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Release builds on Android use goen's real AdMob ad units; debug/profile
/// builds and iOS (no AdMob iOS app yet) use Google's official TEST ad unit
/// IDs (https://developers.google.com/admob/flutter/test-ads), which always
/// serve test creatives, so development never generates invalid traffic.
class AdService {
  AdService._();

  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';

  static const _bannerAndroid = 'ca-app-pub-5058227312086483/2723095121';
  static const _interstitialAndroid =
      'ca-app-pub-5058227312086483/9988350787';

  static String get bannerAdUnitId {
    if (Platform.isIOS) return _testBannerIOS;
    return kReleaseMode ? _bannerAndroid : _testBannerAndroid;
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) return _testInterstitialIOS;
    return kReleaseMode ? _interstitialAndroid : _testInterstitialAndroid;
  }

  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      _logger.i('📢 AdMob initialized');
    } catch (e) {
      _logger.e('❌ AdMob initialization failed: $e');
    }
  }
}

/// 対局終了時など、節目でインタースティシャル広告を出すためのコント
/// ローラー。事前ロード(preload)しておき、見せたいタイミングでshow()を
/// 呼ぶ。ロードが間に合っていなければ何も表示せず静かに諦める
/// (対局結果画面を広告待ちでブロックしたくないため)。
class InterstitialAdController {
  InterstitialAd? _ad;
  bool _isLoading = false;

  void preload() {
    if (_ad != null || _isLoading) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _logger.w('Interstitial ad failed to load: $error');
          _isLoading = false;
        },
      ),
    );
  }

  Future<void> showIfAvailable() async {
    final ad = _ad;
    if (ad == null) return;
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload(); // 次回の対局終了に備えて次の1本を先読みしておく
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logger.w('Interstitial ad failed to show: $error');
        ad.dispose();
      },
    );
    await ad.show();
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

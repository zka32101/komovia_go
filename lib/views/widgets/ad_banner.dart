import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/services/ad_service.dart';
import 'package:komovia_go/viewmodels/index.dart';

final _logger = Logger();

/// 画面下部に置くバナー広告。プレミアム会員には広告を出さない
/// （shouldShowAdsProviderを見て、falseなら何も描画しない）。
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _logger.w('Banner ad failed to load: $error');
          ad.dispose();
          _scheduleRetry();
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  /// 読み込み失敗時、一時的なネットワーク不調などから自動で復帰できるよう
  /// 指数バックオフで再試行する（永久に非表示になったままだと広告枠から
  /// 収益が一切上がらなくなるため）。最大試行回数に達したら諦める
  /// （ウィジェットを再マウントすれば initState からまた最初から試せる）。
  void _scheduleRetry() {
    if (!mounted) return;
    final delay = AdRetryPolicy.delayForAttempt(_retryCount + 1);
    if (delay == null) return;
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!mounted) return;
      _loadBanner();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowAds = ref.watch(shouldShowAdsProvider);
    if (!shouldShowAds) return const SizedBox.shrink();

    final ad = _bannerAd;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

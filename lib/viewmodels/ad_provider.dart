import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/services/ad_service.dart';
import 'package:komovia_go/viewmodels/auth_provider.dart';

/// アプリ全体で1つのインタースティシャル広告を使い回す。
/// autoDisposeにしない: 対局結果画面を抜けても次回の対局終了まで
/// 先読み済みの広告を保持しておきたいため。
final interstitialAdControllerProvider = Provider<InterstitialAdController>((ref) {
  final controller = InterstitialAdController();
  controller.preload();
  ref.onDispose(controller.dispose);
  return controller;
});

/// 対局終了時にインタースティシャル広告を表示する。プレミアム会員には
/// 出さない。
final showGameEndInterstitialProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final isSubscriptionActive = ref.read(isSubscriptionActiveProvider);
    if (isSubscriptionActive) return;
    await ref.read(interstitialAdControllerProvider).showIfAvailable();
  };
});

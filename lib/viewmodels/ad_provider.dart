import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/services/ad_service.dart';
import 'package:komovia_go/services/interstitial_ad_policy.dart';
import 'package:komovia_go/viewmodels/game_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

final interstitialAdPolicyProvider =
    Provider<InterstitialAdPolicy>((ref) => const InterstitialAdPolicy());

/// 対局終了時にインタースティシャル広告を表示する。プレミアム会員
/// (広告除去)には一切出さない。それ以外も[InterstitialAdPolicy]に従い、
/// 新規猶予・頻度・最低手数・クールダウンで大幅に絞る。
final showGameEndInterstitialProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (!ref.read(shouldShowAdsProvider)) return;
    final policy = ref.read(interstitialAdPolicyProvider);
    final moves = ref.read(movesCountProvider);
    if (!policy.countsTowardFrequency(moves)) return;
    try {
      final store = InterstitialAdStateStore(await SharedPreferences.getInstance());
      final games = await store.incrementQualifyingGames();
      final now = DateTime.now();
      final show = policy.shouldShow(
        adsEnabled: ref.read(shouldShowAdsProvider),
        movesPlayed: moves,
        qualifyingGamesCompleted: games,
        lastShownAt: store.lastShownAt,
        now: now,
      );
      if (!show) return;
      final shown = await ref.read(interstitialAdControllerProvider).showIfAvailable();
      if (shown) await store.recordShown(now);
    } catch (_) {
      // 広告は best-effort。失敗しても対局結果画面を妨げない。
    }
  };
});

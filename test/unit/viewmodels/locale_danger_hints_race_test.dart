import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/viewmodels/locale_provider.dart';
import 'package:komovia_go/viewmodels/danger_hints_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocaleNotifier/DangerHintsNotifierは、どちらもコンストラクタから
/// 非同期の_load()（SharedPreferencesを読んでstateを復元）を発火する。
/// もしユーザーがアプリ起動直後の一瞬（_load()のawaitがまだ解決していない
/// 間）に設定画面で選択を変えると、setLocale()/set()はstateを即座に
/// 正しい値へ更新するが、その後_load()が完了した時点で保留中だった
/// 「古い/未設定の」値でstateを問答無用に上書きしてしまっていた
/// （ディスクには正しい値が保存済みでも、UI上はロールバックして見える）。
void main() {
  group('LocaleNotifier stale-state race', () {
    test(
        'calling setLocale() before the constructor\'s pending _load() '
        'resolves is not reverted once _load() finishes', () async {
      SharedPreferences.setMockInitialValues({'app_locale_code': 'ja'});

      final notifier = LocaleNotifier();
      // _load()が開始済みだが、まだSharedPreferences.getInstance()のawaitを
      // 抜けていないタイミングで、ユーザーが明示的に言語を変更したと仮定する。
      // awaitせずに発火することで、setLocale()自身のawaitもまだ未解決の
      // ままにしておく。
      // ignore: unawaited_futures
      notifier.setLocale(const Locale('en'));

      // 両方の非同期処理（_load()とsetLocale()）が完了するまで待つ。
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.languageCode, 'en');
    });

    test('_load() still restores a previously saved locale when setLocale() '
        'was never called', () async {
      SharedPreferences.setMockInitialValues({'app_locale_code': 'en'});

      final notifier = LocaleNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.languageCode, 'en');
    });
  });

  group('DangerHintsNotifier stale-state race', () {
    test(
        'calling set() before the constructor\'s pending _load() resolves '
        'is not reverted once _load() finishes', () async {
      SharedPreferences.setMockInitialValues({'go_danger_hints': true});

      final notifier = DangerHintsNotifier();
      // ignore: unawaited_futures
      notifier.set(false);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state, isFalse);
    });

    test('_load() still restores a previously saved value when set() was '
        'never called', () async {
      SharedPreferences.setMockInitialValues({'go_danger_hints': false});

      final notifier = DangerHintsNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state, isFalse);
    });
  });
}

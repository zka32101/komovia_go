import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefLocaleCode = 'app_locale_code';

/// アプリの表示言語。既存ユーザーの見え方を変えないよう、保存された
/// 選択が無い間は日本語をデフォルトにする（英語ロケール端末でも同じ）。
class LocaleNotifier extends StateNotifier<Locale> {
  // setLocale()が_load()より先に完了した場合、_load()の保留中だった
  // 読み込みが完了した時点でユーザーの新しい選択をstateで上書きして
  // しまっていた(ディスクには正しい値が保存済みでも、UI上はロールバック
  // して見える)。アプリ起動直後の一瞬(SharedPreferencesのプラグイン
  // チャンネル往復を待つ間)に設定画面で選択を変えるだけで再現する。
  // setLocale()が一度でも呼ばれたら、その後の_load()の結果は破棄する。
  bool _explicitlySet = false;

  LocaleNotifier() : super(const Locale('ja')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_explicitlySet) return;
    final code = prefs.getString(_prefLocaleCode);
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    _explicitlySet = true;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLocaleCode, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

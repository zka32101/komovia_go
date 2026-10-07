import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefLocaleCode = 'app_locale_code';

/// アプリの表示言語。既存ユーザーの見え方を変えないよう、保存された
/// 選択が無い間は日本語をデフォルトにする（英語ロケール端末でも同じ）。
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ja')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefLocaleCode);
    if (code != null) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLocaleCode, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

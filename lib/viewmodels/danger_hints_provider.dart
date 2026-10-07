import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefDangerHints = 'go_danger_hints';

/// 「石の危険を可視化」（アタリの石・打てない点の表示）のオン/オフ。
/// 初心者向けなので、保存された選択が無い間はオン。
class DangerHintsNotifier extends StateNotifier<bool> {
  DangerHintsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefDangerHints);
    if (saved != null) state = saved;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDangerHints, value);
  }
}

final dangerHintsProvider =
    StateNotifierProvider<DangerHintsNotifier, bool>((ref) => DangerHintsNotifier());

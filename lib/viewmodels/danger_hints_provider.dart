import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefDangerHints = 'go_danger_hints';

/// 「石の危険を可視化」（アタリの石・打てない点の表示）のオン/オフ。
/// 初心者向けなので、保存された選択が無い間はオン。
class DangerHintsNotifier extends StateNotifier<bool> {
  // set()が_load()より先に完了した場合、_load()の保留中だった読み込みが
  // 完了した時点でユーザーの新しい選択をstateで上書きしてしまっていた
  // （ディスクには正しい値が保存済みでも、UI上はロールバックして見える）。
  // set()が一度でも呼ばれたら、その後の_load()の結果は破棄する。
  bool _explicitlySet = false;

  DangerHintsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_explicitlySet) return;
    final saved = prefs.getBool(_prefDangerHints);
    if (saved != null) state = saved;
  }

  Future<void> set(bool value) async {
    _explicitlySet = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDangerHints, value);
  }
}

final dangerHintsProvider =
    StateNotifierProvider<DangerHintsNotifier, bool>((ref) => DangerHintsNotifier());

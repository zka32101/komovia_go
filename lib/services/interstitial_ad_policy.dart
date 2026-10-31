import 'package:shared_preferences/shared_preferences.dart';

/// 対局終了時のインタースティシャル広告を「出すかどうか」決める純粋な
/// ポリシー。大人向けプレミアムの体験を壊さないよう、以下を全て満たす
/// 時だけ表示する:
/// - 広告除去の権利(プレミアム会員)を持っていない
/// - 対局が[minMoves]手以上続いた（即投了・短い対局では出さない）
/// - 規定手数以上の対局を[gracePeriodGames]局終えた後（新規ユーザーは猶予）
/// - 猶予期間後、規定対局[frequency]局ごとに1回だけ
/// - 前回表示から[cooldown]以上経過している
class InterstitialAdPolicy {
  const InterstitialAdPolicy({
    this.gracePeriodGames = 5,
    this.frequency = 3,
    this.minMoves = 10,
    this.cooldown = const Duration(minutes: 10),
  });

  final int gracePeriodGames;
  final int frequency;
  final int minMoves;
  final Duration cooldown;

  /// 今回の対局が「数える対局」かどうか（手数しきい値を満たすか）。
  bool countsTowardFrequency(int movesPlayed) => movesPlayed >= minMoves;

  /// [qualifyingGamesCompleted] は今回の対局を含めた、規定手数以上の対局数。
  bool shouldShow({
    required bool adsEnabled,
    required int movesPlayed,
    required int qualifyingGamesCompleted,
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    if (!adsEnabled) return false;
    if (!countsTowardFrequency(movesPlayed)) return false;
    if (qualifyingGamesCompleted <= gracePeriodGames) return false;
    final sinceGrace = qualifyingGamesCompleted - gracePeriodGames;
    if (sinceGrace % frequency != 0) return false;
    if (lastShownAt != null && now.difference(lastShownAt) < cooldown) {
      return false;
    }
    return true;
  }
}

/// ポリシー判定に必要な端末ローカル状態（アカウント同期不要）。
class InterstitialAdStateStore {
  InterstitialAdStateStore(this._prefs);
  final SharedPreferences _prefs;

  static const _gamesKey = 'interstitial_qualifying_games';
  static const _lastShownKey = 'interstitial_last_shown_ms';

  int get qualifyingGames => _prefs.getInt(_gamesKey) ?? 0;

  DateTime? get lastShownAt {
    final ms = _prefs.getInt(_lastShownKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<int> incrementQualifyingGames() async {
    final next = qualifyingGames + 1;
    await _prefs.setInt(_gamesKey, next);
    return next;
  }

  Future<void> recordShown(DateTime at) =>
      _prefs.setInt(_lastShownKey, at.millisecondsSinceEpoch);
}

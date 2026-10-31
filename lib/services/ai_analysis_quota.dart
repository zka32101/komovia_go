import 'package:shared_preferences/shared_preferences.dart';

/// AI振り返りの利用可否の判定結果。
enum AiAnalysisAccess {
  /// AI分析プラン加入者 — 無制限。
  unlimited,

  /// 無料枠の残りがある。
  freeQuota,

  /// 今日の無料枠を使い切った — アップセルを出す。
  blocked,
}

/// AI振り返りの1日あたり無料回数を管理する純粋なポリシー+端末ローカル状態。
///
/// 保存先は既存の[InterstitialAdStateStore]と同じSharedPreferences(アカウント
/// 同期不要の端末ローカル状態)に揃えている。カウンタは「端末ローカルの暦日」
/// 単位で、日付が変わった最初の参照時に0へ戻る(=ローカル時刻の深夜0時リセット)。
/// 他の日次制限機能とは別キーの独立したカウンタ。
class AiAnalysisQuotaStore {
  AiAnalysisQuotaStore(this._prefs, {this.dailyFreeLimit = 3});

  final SharedPreferences _prefs;
  final int dailyFreeLimit;

  static const dateKey = 'ai_analysis_quota_date';
  static const countKey = 'ai_analysis_quota_count';

  static String _dayKey(DateTime now) {
    final l = now.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-'
        '${l.month.toString().padLeft(2, '0')}-'
        '${l.day.toString().padLeft(2, '0')}';
  }

  /// [now]の暦日に使った回数(別日の記録なら0)。
  int usedOn(DateTime now) {
    if (_prefs.getString(dateKey) != _dayKey(now)) return 0;
    return _prefs.getInt(countKey) ?? 0;
  }

  int remaining(DateTime now) =>
      (dailyFreeLimit - usedOn(now)).clamp(0, dailyFreeLimit).toInt();

  AiAnalysisAccess check({required bool hasPlan, required DateTime now}) {
    if (hasPlan) return AiAnalysisAccess.unlimited;
    return remaining(now) > 0
        ? AiAnalysisAccess.freeQuota
        : AiAnalysisAccess.blocked;
  }

  /// 無料枠を1回消費する。
  Future<void> recordUse(DateTime now) async {
    final next = usedOn(now) + 1;
    await _prefs.setString(dateKey, _dayKey(now));
    await _prefs.setInt(countKey, next);
  }
}

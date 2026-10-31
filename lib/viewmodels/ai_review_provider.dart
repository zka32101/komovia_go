import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/index.dart';
import '../services/ai_analysis_quota.dart';
import 'auth_provider.dart';

final _logger = Logger();

final aiExplanationServiceProvider = Provider((ref) => AIExplanationService());

/// 対局後のAI振り返り分析を生成する。sgfDataは対局ごとに異なる長い文字列
/// なので、familyキャッシュにすると際限なく増えてしまう — saveGameRecordProvider
/// と同様、呼び出しの都度実行するプレーンなアクションにする。
final generateGameAnalysisProvider = Provider<
    Future<GameAnalysis> Function({
      required String sgfData,
      required String kifuId,
    })>((ref) {
  final service = ref.watch(aiExplanationServiceProvider);
  return ({required sgfData, required kifuId}) async {
    try {
      final analysis = await service.generateGameAnalysis(
        sgfData: sgfData,
        kifuId: kifuId,
      );
      _logger.i('Generated AI review for $kifuId (${analysis.moves.length} moves)');
      return analysis;
    } catch (e) {
      _logger.e('Error generating AI review: $e');
      rethrow;
    }
  };
});

/// 端末ローカルのAI振り返り無料枠カウンタ。
final aiAnalysisQuotaStoreProvider = FutureProvider<AiAnalysisQuotaStore>((ref) async {
  return AiAnalysisQuotaStore(await SharedPreferences.getInstance());
});

/// 今日の無料枠を使い切ったときに投げる。UIはこれを受けてアップセルを出す。
class AiAnalysisQuotaExceededException implements Exception {
  @override
  String toString() => 'AI analysis daily quota exceeded';
}

/// 利用可否チェック付きのAI振り返り生成。
/// (a) AI分析プラン加入者 → 無条件に許可
/// (b) 無料枠が残っている → 許可し、生成に成功したら1回消費
///     (失敗時は消費しない — 通信エラーで枠が減るのを避けるため)
/// (c) それ以外 → [AiAnalysisQuotaExceededException]
final gatedGenerateGameAnalysisProvider = Provider<
    Future<GameAnalysis> Function({
      required String sgfData,
      required String kifuId,
    })>((ref) {
  return ({required sgfData, required kifuId}) async {
    final now = DateTime.now();
    final user = ref.read(currentUserProvider);
    final store = await ref.read(aiAnalysisQuotaStoreProvider.future);
    final access = store.check(
      hasPlan: user?.hasAiAnalysisPlan(now) ?? false,
      now: now,
    );
    if (access == AiAnalysisAccess.blocked) {
      throw AiAnalysisQuotaExceededException();
    }
    final analysis = await ref.read(generateGameAnalysisProvider)(
      sgfData: sgfData,
      kifuId: kifuId,
    );
    if (access == AiAnalysisAccess.freeQuota) {
      await store.recordUse(now);
    }
    return analysis;
  };
});

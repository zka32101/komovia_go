import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../services/index.dart';

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

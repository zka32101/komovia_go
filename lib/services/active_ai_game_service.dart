import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/active_ai_game.dart';

final _logger = Logger();

/// 進行中AI対局の保存・取得・削除。`active_ai_games/{uid}`
/// （1ユーザー1進行中対局、ドキュメントIDはuidそのもの）。
class ActiveAiGameService {
  final FirebaseFirestore _firestore;

  ActiveAiGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('active_ai_games');

  /// 現在の対局状態を丸ごと上書き保存する（PvpGameと同じ、都度全体書き込み
  /// 方式 - 差分更新ではない）。
  Future<void> save(ActiveAiGame game) async {
    await _collection.doc(game.uid).set(game.toFirestore());
  }

  /// 指定ユーザーの進行中対局（あれば）を取得する。
  Future<ActiveAiGame?> getActive(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return ActiveAiGame.fromFirestore(doc);
  }

  /// 対局終了時（終局・投了）に進行中対局のレコードを消す。
  /// 既に存在しない場合も静かに成功する（終局処理は何度走っても安全）。
  Future<void> clear(String uid) async {
    try {
      await _collection.doc(uid).delete();
    } catch (e) {
      _logger.w('ActiveAiGameService.clear failed (non-fatal): $e');
    }
  }
}

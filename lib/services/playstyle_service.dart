import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/game_record.dart';
// `Friendship` is komovia_core's (uid/friendUid/displayName/status/...) —
// the shape actually returned by FriendService.getFriends, which is what
// every real friends feature (friends_screen.dart, social_features_provider.dart)
// uses.
import 'package:komovia_core/komovia_core.dart' hide GameRecord;
import '../models/playstyle.dart';
import '../utils/sgf_parser.dart';
import 'go_rules.dart';

final _logger = Logger();

/// 棋風の相性 - 過去の対局から棋風を分析し、補完し合う/似た相手を推奨する
class PlaystyleService {
  final FirebaseFirestore _firestore;

  PlaystyleService(this._firestore);

  /// 棋譜(sgfData、着手順そのものの本物のSGF - BoardState.toSgf()の最終
  /// 局面スナップショット方言ではない)をGoRulesで再生し、対局全体での
  /// 捕獲石数の合計を返す。非合法手やパースできない棋譜は0捕獲として
  /// 無視し(観戦・学習用の再生と同じ寛容な方針)、プロファイル算出全体を
  /// 失敗させない。
  int _countTotalCaptures(GameRecord record) {
    try {
      final moves = parseSgfMoves(record.sgfData);
      if (moves.isEmpty) return 0;
      final boardSize = parseSgfBoardSize(record.sgfData);

      var stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      int? koRow;
      int? koCol;
      var totalCaptures = 0;

      for (final move in moves) {
        if (move.isPass) continue;
        if (move.row < 0 ||
            move.row >= boardSize ||
            move.col < 0 ||
            move.col >= boardSize) {
          continue;
        }
        final result = GoRules.applyMove(
          stones: stones,
          boardSize: boardSize,
          row: move.row,
          col: move.col,
          player: move.player,
          koRow: koRow,
          koCol: koCol,
        );
        if (result == null) continue;
        stones = result.stones;
        koRow = result.koRow;
        koCol = result.koCol;
        totalCaptures += result.capturedCount;
      }
      return totalCaptures;
    } catch (e) {
      _logger.w('Could not replay SGF for capture count: $e');
      return 0;
    }
  }

  /// ユーザーの対局記録から棋風プロファイルを算出して保存する
  Future<PlaystyleProfile> computeAndSaveProfile(String uid) async {
    try {
      final snapshots = await _firestore
          .collection('gameRecords')
          .where('uid', isEqualTo: uid)
          .orderBy('playedAt', descending: true)
          .limit(50)
          .get();

      if (snapshots.docs.isEmpty) {
        final empty = PlaystyleProfile.empty(uid);
        await _firestore.collection('playstyle_profiles').doc(uid).set(empty.toFirestore());
        return empty;
      }

      double totalAggressiveness = 0;
      double totalTerritoriality = 0;
      double totalSacrifice = 0;
      int counted = 0;

      for (final doc in snapshots.docs) {
        final record = GameRecord.fromFirestore(doc);
        final moves = record.movesCount ?? 0;
        if (moves <= 0) continue;

        // 捕獲の多さ = 戦闘の多さ（攻撃的な棋風の指標）。以前はここが
        // |blackScore - whiteScore|（最終スコア差、つまり地合いの差）を
        // 「捕獲数」と称して使っており、下のterritorialityと変数が完全に
        // 同一だったため、aggressiveness + territorialityが常に1に
        // 固定されてしまい、2軸が独立して変動できなかった(接戦で激しく
        // 打ち合った対局は「捕獲が少ない=消極的」と誤判定され、逆に
        // 一方的な地合い勝ちの静かな対局は「捕獲が多い=攻撃的」と誤判定
        // されていた)。GameRecord自体には捕獲数フィールドが無いため、
        // 棋譜(sgfData、着手順そのもの)をGoRulesで再生して実際の捕獲数を
        // 数える。
        final captures = _countTotalCaptures(record).toDouble();
        final aggressiveness = (captures / (moves + 1)).clamp(0.0, 1.0);

        // スコア差の小ささ = 地合い重視で堅実に打つ棋風の指標
        final scoreDiff = ((record.blackScore ?? 0) - (record.whiteScore ?? 0)).abs();
        final territoriality = (1.0 - (scoreDiff / (moves + 1)).clamp(0.0, 1.0));

        // 手数に対する捕獲頻度 = 捨て石を厭わない打ち方の指標
        final sacrificeRate = (captures / (moves + 1) * 2).clamp(0.0, 1.0);

        totalAggressiveness += aggressiveness;
        totalTerritoriality += territoriality;
        totalSacrifice += sacrificeRate;
        counted++;
      }

      final profile = counted == 0
          ? PlaystyleProfile.empty(uid)
          : PlaystyleProfile(
              uid: uid,
              aggressiveness: totalAggressiveness / counted,
              territoriality: totalTerritoriality / counted,
              sacrificeRate: totalSacrifice / counted,
              gamesAnalyzed: counted,
              updatedAt: DateTime.now(),
            );

      await _firestore
          .collection('playstyle_profiles')
          .doc(uid)
          .set(profile.toFirestore(), SetOptions(merge: true));
      _logger.i('Computed playstyle profile for $uid from $counted games');
      return profile;
    } catch (e) {
      _logger.e('Error computing playstyle profile: $e');
      rethrow;
    }
  }

  Future<PlaystyleProfile> getProfile(String uid) async {
    try {
      final doc = await _firestore.collection('playstyle_profiles').doc(uid).get();
      if (!doc.exists) {
        return PlaystyleProfile.empty(uid);
      }
      return PlaystyleProfile.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error getting playstyle profile: $e');
      rethrow;
    }
  }

  /// フレンド一覧の中から、補完し合う/似た棋風の相手を相性順に返す
  Future<List<PlaystyleCompatibility>> getCompatibleFriends({
    required String uid,
    required List<Friendship> friends,
  }) async {
    try {
      final myProfile = await getProfile(uid);
      final results = <PlaystyleCompatibility>[];

      for (final friend in friends) {
        if (friend.status == 'blocked') continue;
        final otherProfile = await getProfile(friend.friendUid);

        final aggressivenessDiff = (myProfile.aggressiveness - otherProfile.aggressiveness).abs();
        final territorialityDiff = (myProfile.territoriality - otherProfile.territoriality).abs();
        final avgDiff = (aggressivenessDiff + territorialityDiff) / 2;

        // 差が大きいほど「補完し合う」相性、差が小さいほど「似た棋風」の相性
        final compatibilityScore = avgDiff > 0.4 ? avgDiff : (1.0 - avgDiff);
        final compatibilityType = avgDiff > 0.4 ? 'complementary' : 'similar';

        results.add(PlaystyleCompatibility(
          uid: uid,
          otherUid: friend.friendUid,
          otherDisplayName: friend.displayName,
          compatibilityScore: compatibilityScore.clamp(0.0, 1.0),
          compatibilityType: compatibilityType,
        ));
      }

      results.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));
      return results;
    } catch (e) {
      _logger.e('Error getting compatible friends: $e');
      rethrow;
    }
  }
}

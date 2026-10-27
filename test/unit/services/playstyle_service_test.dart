import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/game_record.dart';
import 'package:komovia_go/services/playstyle_service.dart';
import 'package:komovia_go/utils/sgf_parser.dart';

/// PlaystyleService.computeAndSaveProfileの回帰テスト。
///
/// 以前はaggressiveness(攻撃性)の算出に使う「捕獲の多さ」が実際には
/// |blackScore - whiteScore|（最終スコア差）であり、territoriality
/// (地合い重視度)の算出にも同じscoreDiffが使われていたため、
/// aggressiveness + territoriality が常に1に固定され、2軸が独立して
/// 変動できなかった。棋譜を実際にGoRulesで再生して捕獲数を数える
/// ように修正した後は、最終スコアが接戦でも実際に捕獲があれば
/// aggressivenessが0より大きくなることを確認する。
void main() {
  group('PlaystyleService.computeAndSaveProfile', () {
    late FakeFirebaseFirestore firestore;
    late PlaystyleService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PlaystyleService(firestore);
    });

    Future<void> seedGame({
      required List<({int row, int col, String player})> moves,
      required double blackScore,
      required double whiteScore,
    }) async {
      final sgf = generateSgfFromMoves(moves, 9);
      await firestore.collection('gameRecords').add({
        'uid': 'u1',
        'boardSize': 9,
        'sgfData': sgf,
        'result': GameResult.playerWin.name,
        'aiLevel': 5,
        'playedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'movesCount': moves.length,
        'blackScore': blackScore,
        'whiteScore': whiteScore,
      });
    }

    test(
        'a close-score game that actually had a capture gets positive '
        'aggressiveness (regression: previously aggressiveness was '
        'computed from |blackScore - whiteScore|, so a near-tied score '
        'always produced aggressiveness ≈ 0 regardless of real fighting)',
        () async {
      // 白(1,1)を黒が四方から囲んで捕獲する一連の着手。
      await seedGame(
        moves: [
          (row: 1, col: 1, player: 'white'),
          (row: 0, col: 1, player: 'black'),
          (row: 5, col: 5, player: 'white'),
          (row: 1, col: 0, player: 'black'),
          (row: 5, col: 6, player: 'white'),
          (row: 2, col: 1, player: 'black'),
          (row: 5, col: 7, player: 'white'),
          (row: 1, col: 2, player: 'black'), // captures white at (1,1)
        ],
        blackScore: 40,
        whiteScore: 40, // 完全な接戦
      );

      final profile = await service.computeAndSaveProfile('u1');

      expect(profile.aggressiveness, greaterThan(0));
    });

    test(
        'aggressiveness and territoriality are not forced to sum to 1 '
        '(regression guard for the same bug)', () async {
      await seedGame(
        moves: [
          (row: 1, col: 1, player: 'white'),
          (row: 0, col: 1, player: 'black'),
          (row: 5, col: 5, player: 'white'),
          (row: 1, col: 0, player: 'black'),
          (row: 5, col: 6, player: 'white'),
          (row: 2, col: 1, player: 'black'),
          (row: 5, col: 7, player: 'white'),
          (row: 1, col: 2, player: 'black'),
        ],
        blackScore: 40,
        whiteScore: 40,
      );

      final profile = await service.computeAndSaveProfile('u1');

      expect(profile.aggressiveness + profile.territoriality, isNot(1.0));
    });

    test('a game with no actual captures has zero aggressiveness even if '
        'the final score is lopsided', () async {
      await seedGame(
        moves: [
          (row: 0, col: 0, player: 'black'),
          (row: 8, col: 8, player: 'white'),
          (row: 0, col: 1, player: 'black'),
          (row: 8, col: 7, player: 'white'),
        ],
        blackScore: 60,
        whiteScore: 20,
      );

      final profile = await service.computeAndSaveProfile('u1');

      expect(profile.aggressiveness, 0.0);
    });
  });
}

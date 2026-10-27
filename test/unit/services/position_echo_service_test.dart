import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/position_echo_service.dart';

void main() {
  group('PositionEchoService._findHistoricalMatch (via recordPositionReached)', () {
    late FakeFirebaseFirestore firestore;
    late PositionEchoService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PositionEchoService(firestore);
    });

    Future<void> seedKifu({
      required String id,
      required String sgfData,
    }) {
      final kifu = KifuLibrary(
        id: id,
        title: 'Test Kifu',
        sgfData: sgfData,
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'test',
        createdAt: DateTime(2020, 1, 1),
      );
      return firestore
          .collection('kifuLibrary')
          .doc(id)
          .set(kifu.toFirestore());
    }

    test(
        'matches a live board against a real-dialect (no-comma) kifuLibrary '
        'SGF - the real bug this fixes was using a parser that only '
        'understood the comma-separated self-play dialect, so real kifu '
        'SGF never matched anything', () async {
      // Real SGF dialect, as actually stored in kifuLibrary: two-letter
      // coordinates, no comma. Two moves: B[cc] (black at row/col 2,2 on a
      // 9x9 board), W[gg] (white at row/col 6,6).
      await seedKifu(id: 'kifu1', sgfData: '(;GM[1]SZ[9];B[cc];W[gg])');

      final board = BoardState(
        boardSize: 9,
        stones: List.generate(9, (row) {
          return List.generate(9, (col) {
            if (row == 2 && col == 2) return 1; // black
            if (row == 6 && col == 6) return 2; // white
            return 0;
          });
        }),
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: true,
      );

      final echo = await service.recordPositionReached(
        uid: 'player1',
        displayName: 'Player One',
        board: board,
        moveNumber: 2,
      );

      expect(echo.kifuId, 'kifu1');
    });

    test(
        'does not false-positive match an empty board against an '
        'unrelated kifu with real moves (confirms the fixed parser actually '
        'replays moves rather than silently producing an empty board again)',
        () async {
      await seedKifu(id: 'kifu2', sgfData: '(;GM[1]SZ[9];B[cc];W[gg])');

      final emptyBoard = BoardState(
        boardSize: 9,
        stones: List.generate(9, (_) => List.filled(9, 0)),
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: true,
      );

      final echo = await service.recordPositionReached(
        uid: 'player2',
        displayName: 'Player Two',
        board: emptyBoard,
        moveNumber: 0,
      );

      expect(echo.kifuId, isNull);
    });
  });
}

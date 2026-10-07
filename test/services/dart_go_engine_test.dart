import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/dart_go_engine.dart';
import 'package:komovia_go/services/fuego_engine_service.dart';
import 'package:komovia_go/services/go_rules.dart';

List<int> _flat(List<List<int>> rows) => [for (final r in rows) ...r];

List<List<int>> _empty(int n) => List.generate(n, (_) => List.filled(n, 0));

(int, int)? _move(
  List<List<int>> stones,
  int size,
  int player, {
  int level = 10,
  int koIndex = -1,
  int seed = 1,
  int playouts = 300,
}) {
  return DartGoEngine.chooseMoveSync(
    board: _flat(stones),
    size: size,
    player: player,
    level: level,
    koIndex: koIndex,
    seed: seed,
    maxPlayouts: playouts,
    budgetMs: 5000,
  );
}

void main() {
  group('DartGoEngine', () {
    test('plays a legal point on an empty board', () {
      for (final size in [9, 13, 19]) {
        final m = _move(_empty(size), size, 1, playouts: 30);
        expect(m, isNotNull);
        expect(m!.$1, inInclusiveRange(0, size - 1));
        expect(m.$2, inInclusiveRange(0, size - 1));
      }
    });

    test('captures a stone in atari', () {
      final b = _empty(9);
      b[4][4] = 1; // black stone
      b[3][4] = 2;
      b[4][3] = 2;
      b[4][5] = 2; // white surrounds on three sides
      final m = _move(b, 9, 2, playouts: 3000);
      expect(m, equals((5, 4)));
    });

    test('extends a group that is in atari', () {
      final b = _empty(9);
      b[4][4] = 2; // white stone with one liberty left at (5,4)
      b[3][4] = 1;
      b[4][3] = 1;
      b[4][5] = 1;
      expect(_move(b, 9, 2, playouts: 1000), equals((5, 4)));
    });

    test('never fills its own eye', () {
      final b = _empty(9);
      // White group with an eye at the corner (0,0).
      b[0][1] = 2;
      b[1][0] = 2;
      b[1][1] = 2;
      b[5][5] = 1; // a black stone elsewhere so the board is not empty
      for (var seed = 0; seed < 5; seed++) {
        final m = _move(b, 9, 2, seed: seed, playouts: 100);
        expect(m, isNot(equals((0, 0))));
      }
    });

    test('passes when the only legal point is its own eye', () {
      final b = List.generate(9, (_) => List.filled(9, 2));
      b[0][0] = 0;
      expect(_move(b, 9, 2, playouts: 50), isNull);
    });

    test('respects the ko point', () {
      // Classic ko shape on 9x9 around (1,1).
      final b = _empty(9);
      b[0][1] = 1;
      b[1][0] = 1;
      b[2][1] = 1;
      b[1][2] = 2; // white stone that black just captured next to...
      b[0][2] = 2;
      b[2][2] = 2;
      b[1][3] = 2;
      // (1,1) is empty and is the ko point: white may not retake at once.
      final m = _move(b, 9, 2, koIndex: 1 * 9 + 1, playouts: 100);
      expect(m, isNot(equals((1, 1))));
    });

    test('always returns a legal move on random positions', () {
      final rng = math.Random(7);
      for (final size in [9, 13]) {
        for (var game = 0; game < 6; game++) {
          var stones = _empty(size);
          int? koR;
          int? koC;
          var player = 1;
          final plies = 10 + rng.nextInt(40);
          for (var i = 0; i < plies; i++) {
            final r = rng.nextInt(size);
            final c = rng.nextInt(size);
            final res = GoRules.applyMove(
              stones: stones,
              boardSize: size,
              row: r,
              col: c,
              player: player,
              koRow: koR,
              koCol: koC,
            );
            if (res == null) continue;
            stones = res.stones;
            koR = res.koRow;
            koC = res.koCol;
            player = 3 - player;
          }
          final m = DartGoEngine.chooseMoveSync(
            board: _flat(stones),
            size: size,
            player: player,
            level: 3,
            koIndex: (koR != null && koC != null) ? koR * size + koC : -1,
            seed: game,
            maxPlayouts: 60,
            budgetMs: 5000,
          );
          if (m == null) continue; // pass is always legal
          expect(
            GoRules.isLegalMove(
              stones: stones,
              boardSize: size,
              row: m.$1,
              col: m.$2,
              player: player,
              koRow: koR,
              koCol: koC,
            ),
            isTrue,
            reason: 'size=$size game=$game move=$m',
          );
        }
      }
    });

    test('async API works through an isolate and finishes quickly', () async {
      final b = _empty(9);
      b[4][4] = 1;
      final sw = Stopwatch()..start();
      final m = await DartGoEngine.chooseMove(
        stones: b,
        boardSize: 9,
        player: 2,
        aiLevel: 5,
      );
      sw.stop();
      expect(m, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(4000));
    });
  });

  group('FuegoEngineService without native library', () {
    test('requestAiMove falls back to the Dart engine', () async {
      final service = FuegoEngineService();
      final b = _empty(9);
      b[4][4] = 1;
      final move = await service.requestAiMove(
        boardSize: 9,
        stones: b,
        isPlayerBlack: true,
        aiLevel: 4,
      );
      if (!move.isPass) {
        expect(
          GoRules.isLegalMove(
            stones: b,
            boardSize: 9,
            row: move.row,
            col: move.col,
            player: 2,
          ),
          isTrue,
        );
      }
      service.dispose();
    });
  });
}

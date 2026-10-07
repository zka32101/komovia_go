import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/fuego_engine_service.dart';
import 'package:komovia_go/services/go_rules.dart';
import 'package:komovia_go/services/go_scoring.dart';

void main() {
  group('Fuego Engine Service', () {
    FuegoEngineService? engineService;

    setUpAll(() {
      // Fuego エンジンを初期化
      try {
        engineService = FuegoEngineService();
      } on Exception catch (e) {
        // Fuego ライブラリが見つからない場合はスキップ
        print('⚠️ Fuego initialization skipped: $e');
        print('💡 ネイティブライブラリを配置してください: android/app/src/main/jniLibs/arm64-v8a/libfuego.so');
      }
    });

    tearDownAll(() {
      engineService?.dispose();
    });

    test('AIMove should be created correctly', () {
      final move = AIMove(row: 3, col: 4, confidence: 0.9);

      expect(move.row, equals(3));
      expect(move.col, equals(4));
      expect(move.confidence, equals(0.9));
      expect(move.toString(), contains('AIMove'));
    });

    test('AIMove.fromJson should parse correctly', () {
      final json = {
        'row': 5,
        'col': 6,
        'confidence': 0.85,
        'reasoning': 'Test move',
      };

      final move = AIMove.fromJson(json);

      expect(move.row, equals(5));
      expect(move.col, equals(6));
      expect(move.confidence, equals(0.85));
      expect(move.reasoning, equals('Test move'));
    });

    test('GameEndResult should calculate winner correctly', () {
      final result = GameEndResult(
        gameEnded: true,
        blackScore: 30.0,
        whiteScore: 25.0,
        winner: 'black',
      );

      expect(result.gameEnded, isTrue);
      expect(result.blackScore, equals(30.0));
      expect(result.winner, equals('black'));
      expect(result.deadStoneCount, equals(0));
    });

    test('GameEndResult should carry the dead stone count', () {
      final result = GameEndResult(
        gameEnded: true,
        blackScore: 34.0,
        whiteScore: 27.75,
        winner: 'black',
        deadStoneCount: 3,
      );

      expect(result.deadStoneCount, equals(3));
      expect(result.toString(), contains('deadStones: 3'));
    });

    test('AIMove.isPass should detect the native pass signal', () {
      expect(AIMove(row: -1, col: -1).isPass, isTrue);
      expect(AIMove(row: -1, col: 4).isPass, isTrue);
      expect(AIMove(row: 4, col: 4).isPass, isFalse);
    });

    test('FuegoEngineService.validateMove should verify legal positions', () {
      final engine = engineService;
      if (engine == null) return; // native Fuego library unavailable

      final boardSize = 9;
      final stones = List.generate(
        boardSize,
        (_) => List.filled(boardSize, 0),
      );

      // 空いている位置は合法
      expect(
        engine.validateMove(
          boardSize: boardSize,
          stones: stones,
          row: 4,
          col: 4,
          player: 1,
        ),
        isTrue,
      );

      // 既に石がある位置は非合法
      stones[3][3] = 1;
      expect(
        engine.validateMove(
          boardSize: boardSize,
          stones: stones,
          row: 3,
          col: 3,
          player: 2,
        ),
        isFalse,
      );

      // ボード外は非合法
      expect(
        engine.validateMove(
          boardSize: boardSize,
          stones: stones,
          row: -1,
          col: 4,
          player: 1,
        ),
        isFalse,
      );

      expect(
        engine.validateMove(
          boardSize: boardSize,
          stones: stones,
          row: 9,
          col: 4,
          player: 1,
        ),
        isFalse,
      );
    });

    test('FuegoEngineService.validateMove should reject suicide moves', () {
      final engine = engineService;
      if (engine == null) return; // native Fuego library unavailable

      final boardSize = 9;
      final stones = List.generate(
        boardSize,
        (_) => List.filled(boardSize, 0),
      );
      // Surround (4,4) with black stones so white cannot play there.
      stones[3][4] = 1;
      stones[5][4] = 1;
      stones[4][3] = 1;
      stones[4][5] = 1;

      expect(
        engine.validateMove(
          boardSize: boardSize,
          stones: stones,
          row: 4,
          col: 4,
          player: 2,
        ),
        isFalse,
        reason: 'White playing into a fully-surrounded point is suicide',
      );
    });

    test('GoRules.applyMove should capture a surrounded group', () {
      final boardSize = 9;
      final stones = List.generate(
        boardSize,
        (_) => List.filled(boardSize, 0),
      );
      // White stone at (4,4) surrounded on three sides by black; black
      // plays the fourth liberty to capture it.
      stones[3][4] = 1;
      stones[5][4] = 1;
      stones[4][3] = 1;
      stones[4][4] = 2;

      final result = GoRules.applyMove(
        stones: stones,
        boardSize: boardSize,
        row: 4,
        col: 5,
        player: 1,
      );

      expect(result, isNotNull);
      expect(result!.capturedCount, equals(1));
      expect(result.stones[4][4], equals(0));
      expect(result.stones[4][5], equals(1));
    });

    test('GoRules.applyMove should enforce the simple ko rule', () {
      final boardSize = 9;
      // Lone white stone at (1,1) with a single liberty at (2,1); black
      // fills it to capture, creating a ko at (1,1).
      final stones = List.generate(
        boardSize,
        (_) => List.filled(boardSize, 0),
      );
      stones[0][1] = 1; // black
      stones[1][0] = 1; // black
      stones[1][2] = 1; // black
      stones[1][1] = 2; // white, one liberty at (2,1)

      final capture = GoRules.applyMove(
        stones: stones,
        boardSize: boardSize,
        row: 2,
        col: 1,
        player: 1,
      );
      expect(capture, isNotNull);
      expect(capture!.capturedCount, equals(1));
      expect(capture.stones[1][1], equals(0));
      expect(capture.koRow, equals(1));
      expect(capture.koCol, equals(1));

      // White immediately trying to recapture at (1,1) is forbidden by
      // the simple ko rule.
      final recapture = GoRules.applyMove(
        stones: capture.stones,
        boardSize: boardSize,
        row: 1,
        col: 1,
        player: 2,
        koRow: capture.koRow,
        koCol: capture.koCol,
      );
      expect(recapture, isNull);
    });

    test('GameEndResult.fromJson should parse correctly', () {
      final json = {
        'gameEnded': true,
        'blackScore': 32.5,
        'whiteScore': 28.75,
        'winner': 'black',
        'scoringMethod': 'chinese',
      };

      final result = GameEndResult.fromJson(json);

      expect(result.gameEnded, isTrue);
      expect(result.blackScore, equals(32.5));
      expect(result.whiteScore, equals(28.75));
      expect(result.winner, equals('black'));
      expect(result.scoringMethod, equals('chinese'));
    });

    test('FuegoEngineService should handle empty board', () {
      final engine = engineService;
      if (engine == null) return; // native Fuego library unavailable

      final boardSize = 9;
      final stones = List.generate(
        boardSize,
        (_) => List.filled(boardSize, 0),
      );

      // Empty board should have all legal positions
      for (int row = 0; row < boardSize; row++) {
        for (int col = 0; col < boardSize; col++) {
          expect(
            engine.validateMove(
              boardSize: boardSize,
              stones: stones,
              row: row,
              col: col,
              player: 1,
            ),
            isTrue,
            reason: 'Empty board position ($row, $col) should be legal',
          );
        }
      }
    });

    test('FuegoException should format message correctly', () {
      final exception = FuegoException('Test error', Exception('Cause'));

      expect(
        exception.toString(),
        contains('FuegoException: Test error'),
      );
      expect(
        exception.toString(),
        contains('caused by'),
      );
    });

    // 注: 実際の Fuego AI 呼び出しテストは
    // ネイティブライブラリが必要なため、
    // 統合テストで実行してください
    //
    // flutter test test/fuego_engine_integration_test.dart

    test('GoRules.groupAt should return the connected same-colored group', () {
      final boardSize = 9;
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      stones[0][0] = 1;
      stones[0][1] = 1; // connected to (0,0)
      stones[1][1] = 1; // connected to (0,1)
      stones[5][5] = 1; // separate black stone, not connected

      final group = GoRules.groupAt(stones, boardSize, 0, 0);
      expect(group, {(0, 0), (0, 1), (1, 1)});
      expect(group.contains((5, 5)), isFalse);
    });

    test('GoRules.groupAt should return an empty set for an empty point', () {
      final boardSize = 9;
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      expect(GoRules.groupAt(stones, boardSize, 4, 4), isEmpty);
    });

    test('GoScoring.withDeadStonesRemoved should clear only the given points', () {
      final boardSize = 9;
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      stones[0][0] = 1;
      stones[0][1] = 1;
      stones[3][3] = 2;

      final result = GoScoring.withDeadStonesRemoved(stones, const {(0, 0), (0, 1)});

      expect(result[0][0], equals(0));
      expect(result[0][1], equals(0));
      expect(result[3][3], equals(2), reason: 'Untouched points keep their original value');
      // The original board is not mutated.
      expect(stones[0][0], equals(1));
    });

    test('GoScoring.withDeadStonesRemoved should return the same board for an empty set', () {
      final boardSize = 9;
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      stones[2][2] = 1;

      final result = GoScoring.withDeadStonesRemoved(stones, const {});
      expect(result, same(stones));
    });

    test('FuegoEngineService.scoreWithDeadStones should exclude dead points from scoring', () {
      final engine = engineService;
      if (engine == null) return;

      final boardSize = 9;
      // A black group deep inside white's wall: everything black-adjacent
      // this black group touches is already fully enclosed by white, so
      // marking it dead flips that area to white's territory.
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 2));
      stones[4][4] = 1;
      stones[4][5] = 1;

      final aliveResult = engine.scoreWithDeadStones(
        boardSize: boardSize,
        stones: stones,
        deadPoints: const {},
      );
      expect(aliveResult.deadStoneCount, equals(0));
      expect(aliveResult.blackScore, equals(2.0));

      final deadResult = engine.scoreWithDeadStones(
        boardSize: boardSize,
        stones: stones,
        deadPoints: const {(4, 4), (4, 5)},
      );
      expect(deadResult.deadStoneCount, equals(2));
      expect(deadResult.blackScore, equals(0.0));
      expect(deadResult.winner, equals('white'));
    });

    test('FuegoEngineService.suggestDeadStones should fall back to no suggestions '
        'when the native safety solver is unavailable', () {
      final engine = engineService;
      if (engine == null) return;

      final boardSize = 9;
      final stones = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      stones[4][4] = 1;

      // This sandbox never bundles libfuego.so, so supportsDeadStoneDetection
      // is false and this must return an empty list rather than throwing.
      final suggestions = engine.suggestDeadStones(stones: stones, boardSize: boardSize);
      expect(suggestions, isEmpty);
    });
  });
}

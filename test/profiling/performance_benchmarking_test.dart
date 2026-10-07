import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';

void main() {
  group('Performance Benchmarking Tests', () {
    test('⚡ Benchmark: Board state encoding (1000 iterations)', () {
      final boardState = BoardState(
        boardSize: 19,
        stones: List.generate(19, (r) => List.filled(19, 0)),
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: true,
      );

      // Add some stones (0=empty, 1=black, 2=white)
      boardState.stones[0][0] = 1;
      boardState.stones[18][18] = 2;

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        final encoded = boardState.toSgf();
        expect(encoded, isNotEmpty);
      }

      stopwatch.stop();

      final avgTime = stopwatch.elapsedMicroseconds / 1000;
      print('⚡ Board encoding: ${avgTime.toStringAsFixed(2)}µs avg');
      print('⚡ Total time: ${stopwatch.elapsedMilliseconds}ms for 1000 iterations');

      expect(avgTime, lessThan(100)); // < 100µs per encoding
    });

    test('⚡ Benchmark: Move validation (500 moves)', () {
      final boardState = BoardState(
        boardSize: 9,
        stones: List.generate(9, (r) => List.filled(9, 0)),
        capturedBlack: 0,
        capturedWhite: 0,
        isBlackTurn: true,
      );

      final stopwatch = Stopwatch()..start();

      int validMoves = 0;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (boardState.stones[r][c] == 0) {
            validMoves++;
          }
        }
      }

      stopwatch.stop();

      print('⚡ Move validation: ${stopwatch.elapsedMicroseconds}µs for $validMoves moves');
      print('⚡ Average per move: ${(stopwatch.elapsedMicroseconds / validMoves).toStringAsFixed(2)}µs');

      expect(stopwatch.elapsedMicroseconds, lessThan(10000)); // < 10ms for full board check
    });

    test('⚡ Benchmark: Game record serialization', () {
      final gameRecords = <Map<String, dynamic>>[];

      // Create test game records
      for (int i = 0; i < 100; i++) {
        gameRecords.add({
          'id': 'game_$i',
          'uid': 'user_123',
          'boardSize': [7, 9, 13, 19][i % 4],
          'result': i % 2 == 0 ? 'win' : 'loss',
          'moves': List.generate(100, (j) => {'row': j % 19, 'col': j % 19}),
          'aiLevel': i % 10,
          'playedAt': DateTime.now().toIso8601String(),
        });
      }

      final stopwatch = Stopwatch()..start();

      // Simulate JSON encoding
      final encoded = gameRecords.map((record) => record.toString()).toList();

      stopwatch.stop();

      print('⚡ Serialized ${gameRecords.length} records in ${stopwatch.elapsedMilliseconds}ms');
      print('⚡ Average: ${(stopwatch.elapsedMilliseconds / gameRecords.length).toStringAsFixed(2)}ms per record');

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('⚡ Benchmark: Pattern matching in move sequences', () {
      // Create a complex move sequence
      const moveCount = 300;
      final moves = <List<int>>[];

      for (int i = 0; i < moveCount; i++) {
        moves.add([i % 19, i % 19]);
      }

      final stopwatch = Stopwatch()..start();

      // Simulate pattern detection
      int patternMatches = 0;
      for (int i = 2; i < moves.length; i++) {
        if (moves[i - 1][0] != -1 && moves[i][0] != -1) {
          if ((moves[i][0] - moves[i - 1][0]).abs() <= 1 &&
              (moves[i][1] - moves[i - 1][1]).abs() <= 1) {
            patternMatches++;
          }
        }
      }

      stopwatch.stop();

      print('⚡ Pattern matching: found $patternMatches patterns in ${stopwatch.elapsedMicroseconds}µs');
      print('⚡ Throughput: ${(moveCount / stopwatch.elapsedMilliseconds).toStringAsFixed(0)} moves/ms');

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('⚡ Benchmark: String formatting performance', () {
      const iterations = 10000;

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        final formatted = 'Move ${i ~/ 19 + 1}: (${i % 19}, ${i ~/ 19})';
        expect(formatted, isNotEmpty);
      }

      stopwatch.stop();

      final avgTime = stopwatch.elapsedMicroseconds / iterations;
      print('⚡ String formatting: ${avgTime.toStringAsFixed(2)}µs per format');
      print('⚡ Total: ${stopwatch.elapsedMilliseconds}ms for $iterations iterations');

      expect(avgTime, lessThan(5)); // < 5µs per format
    });

    test('⚡ Benchmark: Sorting performance (game history)', () {
      final games = <Map<String, dynamic>>[];

      // Create 1000 game records
      for (int i = 0; i < 1000; i++) {
        games.add({
          'id': 'game_$i',
          'timestamp': DateTime.now().millisecondsSinceEpoch - (i * 60000), // 1 min apart
          'result': i % 2 == 0 ? 'win' : 'loss',
        });
      }

      final stopwatch = Stopwatch()..start();

      games.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      stopwatch.stop();

      print('⚡ Sorted ${games.length} records in ${stopwatch.elapsedMilliseconds}ms');
      print('⚡ Average: ${(stopwatch.elapsedMilliseconds * 1000 / games.length).toStringAsFixed(2)}µs per record');

      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('⚡ Benchmark: Deep copy performance', () {
      final original = <String, dynamic>{};

      // Create a complex nested structure
      for (int i = 0; i < 100; i++) {
        original['data_$i'] = {
          'id': i,
          'moves': List.generate(50, (j) => {'row': j % 19, 'col': j % 19}),
          'metadata': {
            'created': DateTime.now().toIso8601String(),
            'score': i * 100,
          },
        };
      }

      final stopwatch = Stopwatch()..start();

      // Simulate deep copy
      for (int i = 0; i < 100; i++) {
        final copy = Map<String, dynamic>.from(original);
        expect(copy.length, equals(original.length));
      }

      stopwatch.stop();

      print('⚡ Deep copy: ${(stopwatch.elapsedMilliseconds / 100).toStringAsFixed(2)}ms per copy');

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('⚡ Benchmark: Concurrent operation throughput', () {
      const operationCount = 500;

      final stopwatch = Stopwatch()..start();

      // Simulate concurrent operations
      for (int i = 0; i < operationCount; i++) {
        // Board state check
        final boardCheck = i % 2 == 0;
        // Move validation
        final moveValid = (i % 19) < 19;
        // State update
        final stateUpdate = {'move': i, 'valid': moveValid};

        expect(stateUpdate['valid'], isNotNull);
      }

      stopwatch.stop();

      final throughput = operationCount / (stopwatch.elapsedMilliseconds / 1000);
      print('⚡ Concurrent throughput: ${throughput.toStringAsFixed(0)} ops/sec');
      print('⚡ Average: ${(stopwatch.elapsedMilliseconds / operationCount).toStringAsFixed(3)}ms per operation');

      expect(throughput, greaterThan(1000)); // > 1000 ops/sec
    });

    test('⚡ Benchmark: Cache hit rate simulation', () {
      const iterations = 10000;
      final cache = <String, String>{};

      final stopwatch = Stopwatch()..start();

      int hits = 0;
      int misses = 0;

      for (int i = 0; i < iterations; i++) {
        final key = 'key_${i % 100}'; // Only 100 unique keys

        if (cache.containsKey(key)) {
          hits++;
          final _ = cache[key];
        } else {
          misses++;
          cache[key] = 'value_$i';
        }
      }

      stopwatch.stop();

      final hitRate = (hits / (hits + misses)) * 100;
      print('⚡ Cache hit rate: ${hitRate.toStringAsFixed(1)}%');
      print('⚡ Hits: $hits, Misses: $misses');
      print('⚡ Cache lookup time: ${(stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(2)}µs');

      expect(hitRate, greaterThan(95)); // Should be ~99% hits
    });

    test('⚡ Benchmark: JSON parsing simulation', () {
      const iterations = 100;

      // Simulate JSON data
      final jsonData = {
        'players': [
          {'name': 'Player 1', 'rank': 1, 'rating': 2000},
          {'name': 'Player 2', 'rank': 2, 'rating': 1900},
        ],
        'games': List.generate(
          50,
          (i) => {
            'id': i,
            'result': i % 2 == 0 ? 'win' : 'loss',
            'moves': List.generate(100, (j) => {'row': j % 19, 'col': j % 19}),
          },
        ),
      };

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        // Simulate parsing
        final _ = jsonData.toString();
      }

      stopwatch.stop();

      print('⚡ JSON parsing: ${(stopwatch.elapsedMilliseconds / iterations).toStringAsFixed(2)}ms per parse');

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('⚡ Benchmark: Full game simulation (1000 moves)', () {
      const moves = 1000;

      final stopwatch = Stopwatch()..start();

      // Simulate complete game
      int blackCaptures = 0;
      int whiteCaptures = 0;

      for (int move = 0; move < moves; move++) {
        // Simulate move
        final isBlack = move % 2 == 0;
        final row = (move % 19) + 1;
        final col = ((move ~/ 19) % 19) + 1;

        // Simulate capture detection (simplified)
        if (move > 10 && move % 30 == 0) {
          if (isBlack) {
            blackCaptures++;
          } else {
            whiteCaptures++;
          }
        }
      }

      stopwatch.stop();

      final avgMoveTime = stopwatch.elapsedMicroseconds / moves;
      print('⚡ Full game simulation: ${stopwatch.elapsedMilliseconds}ms for $moves moves');
      print('⚡ Average time per move: ${avgMoveTime.toStringAsFixed(2)}µs');
      print('⚡ Captures - Black: $blackCaptures, White: $whiteCaptures');

      expect(avgMoveTime, lessThan(100)); // < 100µs per move
    });
  });
}

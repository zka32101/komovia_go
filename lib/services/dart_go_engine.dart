import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart Go move generator (flat Monte Carlo with UCB1 root selection).
///
/// Used when the native Fuego library is not bundled with the app, so
/// playing against the AI works offline without any native build.
///
/// Stones are 0=empty, 1=black, 2=white. Scoring is Chinese area scoring
/// with a 3.75 point komi for white, matching FuegoEngineService.
class DartGoEngine {
  DartGoEngine._();

  static const double komi = 3.75;

  /// Picks a move for [player] (1=black, 2=white).
  ///
  /// Returns (row, col), or null when the engine wants to pass. The search
  /// runs in a background isolate so the UI stays responsive.
  static Future<(int, int)?> chooseMove({
    required List<List<int>> stones,
    required int boardSize,
    required int player,
    required int aiLevel,
    int? koRow,
    int? koCol,
  }) {
    final flat = <int>[for (final row in stones) ...row];
    final koIndex = (koRow != null && koCol != null) ? koRow * boardSize + koCol : -1;
    return Isolate.run(
      () => chooseMoveSync(
        board: flat,
        size: boardSize,
        player: player,
        level: aiLevel,
        koIndex: koIndex,
      ),
    );
  }

  /// Synchronous search. [maxPlayouts] / [budgetMs] default to values derived
  /// from [level]; tests pass small explicit values and a [seed].
  static (int, int)? chooseMoveSync({
    required List<int> board,
    required int size,
    required int player,
    required int level,
    int koIndex = -1,
    int? seed,
    int? maxPlayouts,
    int? budgetMs,
  }) {
    final lvl = level.clamp(1, 10);
    final rng = math.Random(seed);
    final playouts = maxPlayouts ?? _playoutsForLevel(lvl, size);
    final budget = budgetMs ?? math.min(600 + 120 * lvl, 1800);

    final root = _Board(size, board)..ko = koIndex;
    final opp = 3 - player;
    final total = size * size;

    var stoneCount = 0;
    for (var i = 0; i < total; i++) {
      if (root.cells[i] != 0) stoneCount++;
    }

    if (stoneCount == 0) {
      final p = size <= 9 ? size ~/ 2 : 3;
      final q = size <= 9 ? size ~/ 2 : 3;
      return (p, q);
    }

    // One stone from each of the player's groups that has a single liberty.
    final atariReps = <int>[];
    final counted = <int>{};
    for (var i = 0; i < total; i++) {
      if (root.cells[i] != player || counted.contains(i)) continue;
      final libs = root.libertiesOf(i);
      counted.addAll(root._group);
      if (libs == 1) atariReps.add(i);
    }

    final near = root.nearStones(2);
    final cands = <_Candidate>[];
    for (var idx = 0; idx < total; idx++) {
      if (root.cells[idx] != 0 || !near[idx]) continue;
      if (root.isOwnEye(idx, player)) continue;
      final trial = root.copy();
      final captured = trial.play(idx, player);
      if (captured < 0) continue;
      final libs = trial.libertiesOf(idx);
      final selfAtari = captured == 0 && libs == 1;
      final saves = atariReps.any(
        (r) => trial.cells[r] == player && trial.libertiesOf(r) >= 2,
      );
      cands.add(_Candidate(idx, trial, captured, selfAtari, libs, saves));
    }

    // Pass is only a real option once the opening is over.
    final passAllowed = stoneCount >= total ~/ 4;
    _Candidate? pass;
    if (passAllowed || cands.isEmpty) {
      final trial = root.copy()..ko = -1;
      pass = _Candidate(-1, trial, 0, false, 0, false);
      cands.add(pass);
    }
    if (cands.length == 1 && cands.first.index == -1) return null;

    cands.shuffle(rng);
    final wins = List<int>.filled(cands.length, 0);
    final visits = List<int>.filled(cands.length, 0);
    // Tactical priors as virtual playouts: captures start out looking good,
    // self-atari moves start out looking bad, so the search focuses on them.
    for (var i = 0; i < cands.length; i++) {
      if (cands[i].captured > 0) {
        final virtual = 6 * math.min<int>(cands[i].captured, 3);
        wins[i] += virtual;
        visits[i] += virtual;
      } else if (cands[i].selfAtari) {
        visits[i] += 6;
      }
    }
    final maxMoves = total + total ~/ 2;
    final clock = Stopwatch()..start();

    var done = 0;
    while (done < playouts && clock.elapsedMilliseconds < budget) {
      int pick;
      if (done < cands.length) {
        pick = done; // visit every candidate once first
      } else {
        pick = 0;
        var best = -1.0;
        final logN = math.log(done + 1);
        for (var i = 0; i < cands.length; i++) {
          final v = visits[i];
          final score = wins[i] / v + 0.6 * math.sqrt(logN / v);
          if (score > best) {
            best = score;
            pick = i;
          }
        }
      }
      final sim = cands[pick].board.copy();
      final diff = _playout(sim, opp, rng, maxMoves);
      final playerWon = player == 1 ? diff > 0 : diff < 0;
      if (playerWon) wins[pick]++;
      visits[pick]++;
      done++;
    }

    // Shrunk mean win rate (priors above already carry the tactical hints).
    final means = List<double>.filled(cands.length, -1);
    for (var i = 0; i < cands.length; i++) {
      if (visits[i] == 0) continue;
      // Shrink toward 50% so a lucky single playout can't top the list.
      means[i] = (wins[i] + 3) / (visits[i] + 6);
    }

    var bestMean = -1.0;
    var bestNonPass = -1.0;
    for (var i = 0; i < cands.length; i++) {
      if (means[i] > bestMean) bestMean = means[i];
      if (cands[i].index != -1 && means[i] > bestNonPass) bestNonPass = means[i];
    }

    // Clear tactics beat noisy playout statistics: take captures, then
    // rescue groups in atari. Weakest levels skip this half the time.
    if (lvl >= 3 || rng.nextBool()) {
      final captures = <int>[
        for (var i = 0; i < cands.length; i++)
          if (cands[i].index != -1 && cands[i].captured > 0 && cands[i].libs >= 2) i,
      ];
      final rescues = <int>[
        for (var i = 0; i < cands.length; i++)
          if (cands[i].index != -1 && cands[i].saves && !cands[i].selfAtari) i,
      ];
      final tactical = captures.isNotEmpty ? captures : rescues;
      if (tactical.isNotEmpty) {
        final best = tactical.reduce((a, b) {
          if (cands[a].captured != cands[b].captured) {
            return cands[a].captured > cands[b].captured ? a : b;
          }
          return means[a] >= means[b] ? a : b;
        });
        final idx = cands[best].index;
        return (idx ~/ size, idx % size);
      }
    }

    if (pass != null) {
      final passMean = means[cands.indexOf(pass)];
      if (passMean >= 0 && (bestNonPass < 0 || passMean >= bestNonPass)) {
        return null;
      }
    }

    // Weaker levels pick loosely among near-best moves.
    final margin = (10 - lvl) * 0.012;
    final pool = <int>[
      for (var i = 0; i < cands.length; i++)
        if (cands[i].index != -1 && means[i] >= 0 && means[i] >= bestNonPass - margin) i,
    ];
    if (pool.isEmpty) return null;

    var chosen = pool[rng.nextInt(pool.length)];
    if (lvl <= 2 && rng.nextDouble() < 0.15) {
      final visited = <int>[
        for (var i = 0; i < cands.length; i++)
          if (cands[i].index != -1 && visits[i] > 0) i,
      ];
      if (visited.isNotEmpty) chosen = visited[rng.nextInt(visited.length)];
    } else if (margin == 0) {
      // Strongest level: best mean, ties broken by visit count.
      chosen = pool.reduce((a, b) {
        if (means[a] != means[b]) return means[a] > means[b] ? a : b;
        return visits[a] >= visits[b] ? a : b;
      });
    }

    final idx = cands[chosen].index;
    return (idx ~/ size, idx % size);
  }

  static int _playoutsForLevel(int level, int size) {
    final base = 40 * level * level; // 40 .. 4000
    final scale = size <= 9 ? 1.0 : (size <= 13 ? 0.6 : 0.35);
    return math.max(30, (base * scale).round());
  }

  /// Random playout to the end; returns black - (white + komi).
  static double _playout(_Board b, int toMove, math.Random rng, int maxMoves) {
    final total = b.n * b.n;
    var color = toMove;
    var passes = 0;
    var moves = 0;
    while (passes < 2 && moves < maxMoves) {
      final start = rng.nextInt(total);
      var played = false;
      for (var k = 0; k < total; k++) {
        var idx = start + k;
        if (idx >= total) idx -= total;
        if (b.cells[idx] != 0) continue;
        if (b.isOwnEye(idx, color)) continue;
        if (b.play(idx, color) >= 0) {
          played = true;
          break;
        }
      }
      passes = played ? 0 : passes + 1;
      color = 3 - color;
      moves++;
    }
    return b.scoreDiff();
  }
}

class _Candidate {
  _Candidate(
    this.index,
    this.board,
    this.captured,
    this.selfAtari,
    this.libs,
    this.saves,
  );

  /// Board index, or -1 for pass.
  final int index;
  final _Board board;
  final int captured;
  final bool selfAtari;

  /// Liberties of the played stone's group after the move.
  final int libs;

  /// True when the move rescues one of the player's groups from atari.
  final bool saves;
}

/// Compact flat-array board used by the search.
class _Board {
  _Board(this.n, List<int> init)
      : cells = Int8List.fromList(init),
        _seen = Int32List(n * n),
        _libSeen = Int32List(n * n),
        _nbrs = _neighborTable(n);

  _Board._copy(_Board o)
      : n = o.n,
        cells = Int8List.fromList(o.cells),
        _seen = Int32List(o.n * o.n),
        _libSeen = Int32List(o.n * o.n),
        _nbrs = o._nbrs,
        ko = o.ko;

  final int n;
  final Int8List cells;
  final Int32List _seen;
  final Int32List _libSeen;
  final List<List<int>> _nbrs;
  final List<int> _group = [];
  int _stamp = 0;

  /// Point that may not be played (simple ko), or -1.
  int ko = -1;

  static final Map<int, List<List<int>>> _tables = {};

  static List<List<int>> _neighborTable(int n) {
    return _tables.putIfAbsent(n, () {
      return List.generate(n * n, (i) {
        final r = i ~/ n;
        final c = i % n;
        return <int>[
          if (r > 0) i - n,
          if (r < n - 1) i + n,
          if (c > 0) i - 1,
          if (c < n - 1) i + 1,
        ];
      });
    });
  }

  _Board copy() => _Board._copy(this);

  /// Flood-fills the group at [start] into [_group]; returns its liberties.
  int _scan(int start) {
    final color = cells[start];
    _stamp++;
    _group
      ..clear()
      ..add(start);
    _seen[start] = _stamp;
    var libs = 0;
    for (var i = 0; i < _group.length; i++) {
      for (final nb in _nbrs[_group[i]]) {
        final v = cells[nb];
        if (v == 0) {
          if (_libSeen[nb] != _stamp) {
            _libSeen[nb] = _stamp;
            libs++;
          }
        } else if (v == color && _seen[nb] != _stamp) {
          _seen[nb] = _stamp;
          _group.add(nb);
        }
      }
    }
    return libs;
  }

  int libertiesOf(int idx) => _scan(idx);

  /// Plays [color] at [idx]. Returns the number of captured stones, or -1
  /// when illegal (occupied, ko, or suicide). Legal moves update [ko].
  int play(int idx, int color) {
    if (cells[idx] != 0 || idx == ko) return -1;
    final opp = 3 - color;
    cells[idx] = color;

    var captured = 0;
    var capturedAt = -1;
    for (final nb in _nbrs[idx]) {
      if (cells[nb] != opp) continue;
      if (_scan(nb) == 0) {
        captured += _group.length;
        capturedAt = _group.first;
        for (final g in _group) {
          cells[g] = 0;
        }
      }
    }

    final ownLibs = _scan(idx);
    if (ownLibs == 0) {
      // Suicide: nothing was captured, so only the placed stone needs undoing.
      cells[idx] = 0;
      return -1;
    }

    ko = (captured == 1 && _group.length == 1) ? capturedAt : -1;
    return captured;
  }

  /// True when [idx] is a single-point eye of [color] (not a false eye).
  bool isOwnEye(int idx, int color) {
    for (final nb in _nbrs[idx]) {
      if (cells[nb] != color) return false;
    }
    final r = idx ~/ n;
    final c = idx % n;
    var bad = 0;
    var off = 0;
    for (final (dr, dc) in const [(-1, -1), (-1, 1), (1, -1), (1, 1)]) {
      final rr = r + dr;
      final cc = c + dc;
      if (rr < 0 || rr >= n || cc < 0 || cc >= n) {
        off++;
        continue;
      }
      if (cells[rr * n + cc] == 3 - color) bad++;
    }
    return off > 0 ? bad == 0 : bad <= 1;
  }

  /// Marks every point within [dist] (Chebyshev) of any stone.
  List<bool> nearStones(int dist) {
    final near = List<bool>.filled(n * n, false);
    for (var i = 0; i < n * n; i++) {
      if (cells[i] == 0) continue;
      final r = i ~/ n;
      final c = i % n;
      for (var dr = -dist; dr <= dist; dr++) {
        for (var dc = -dist; dc <= dist; dc++) {
          final rr = r + dr;
          final cc = c + dc;
          if (rr >= 0 && rr < n && cc >= 0 && cc < n) near[rr * n + cc] = true;
        }
      }
    }
    return near;
  }

  /// Chinese area score: black - (white + komi).
  double scoreDiff() {
    var black = 0;
    var white = 0;
    _stamp++;
    final queue = <int>[];
    for (var i = 0; i < n * n; i++) {
      final v = cells[i];
      if (v == 1) {
        black++;
      } else if (v == 2) {
        white++;
      } else if (_seen[i] != _stamp) {
        queue
          ..clear()
          ..add(i);
        _seen[i] = _stamp;
        var touchB = false;
        var touchW = false;
        for (var q = 0; q < queue.length; q++) {
          for (final nb in _nbrs[queue[q]]) {
            final nv = cells[nb];
            if (nv == 0) {
              if (_seen[nb] != _stamp) {
                _seen[nb] = _stamp;
                queue.add(nb);
              }
            } else if (nv == 1) {
              touchB = true;
            } else {
              touchW = true;
            }
          }
        }
        if (touchB && !touchW) black += queue.length;
        if (touchW && !touchB) white += queue.length;
      }
    }
    return black - (white + DartGoEngine.komi);
  }
}

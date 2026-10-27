import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

void main() {
  group('PuzzleRushService', () {
    late FakeFirebaseFirestore firestore;
    late PuzzleRushService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = PuzzleRushService(firestore: firestore);
    });

    test('startPuzzleRush creates a session with the requested difficulty',
        () async {
      final session = await service.startPuzzleRush(
        uid: 'u1',
        difficulty: 'hard',
      );

      expect(session.uid, 'u1');
      expect(session.difficulty, 'hard');
      expect(session.solvedCount, 0);
      expect(session.score, 0);
    });

    test('solvePuzzle accumulates score/solvedCount/correctCount', () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'normal');

      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'p1',
        puzzleDifficulty: 2,
        isCorrect: true,
        solveTime: 10,
      );
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'p2',
        puzzleDifficulty: 2,
        isCorrect: false,
        solveTime: 15,
      );

      final doc =
          await firestore.collection('puzzleRushSessions').doc(session.id).get();
      final updated = PuzzleRushRecord.fromJson(doc.data()!);

      expect(updated.solvedCount, 2);
      expect(updated.correctCount, 1);
      expect(updated.totalAttempts, 2);
      expect(updated.score, 20); // 10 points * difficultyMultiplier(2)
    });

    test(
        'solvePuzzle never lowers maxCombo even after a miss resets the '
        'current streak (regression: maxCombo used to be overwritten by '
        'the current streak length, so 3連続→1回ミス→1連続正解で3→1に下がっていた)',
        () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'normal');

      // 3連続正解でmaxCombo=3になる。
      for (var i = 0; i < 3; i++) {
        await service.solvePuzzle(
          sessionId: session.id,
          puzzleId: 'p$i',
          puzzleDifficulty: 1,
          isCorrect: true,
          solveTime: 5,
        );
      }
      var doc = await firestore
          .collection('puzzleRushSessions')
          .doc(session.id)
          .get();
      expect(PuzzleRushRecord.fromJson(doc.data()!).maxCombo, 3);

      // 1回ミスして連続が途切れる。maxComboは3のまま保たれるべき。
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'miss',
        puzzleDifficulty: 1,
        isCorrect: false,
        solveTime: 5,
      );
      doc = await firestore
          .collection('puzzleRushSessions')
          .doc(session.id)
          .get();
      expect(PuzzleRushRecord.fromJson(doc.data()!).maxCombo, 3);

      // さらに1連続正解しても、現在の連続数(1)がmaxCombo(3)を上書きしてはいけない。
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'after-miss',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      doc = await firestore
          .collection('puzzleRushSessions')
          .doc(session.id)
          .get();
      expect(PuzzleRushRecord.fromJson(doc.data()!).maxCombo, 3);
    });

    test(
        'solvePuzzle raises maxCombo when a later streak exceeds the '
        'previous best', () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'normal');

      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'miss',
        puzzleDifficulty: 1,
        isCorrect: false,
        solveTime: 5,
      );
      // この後4連続正解すればmaxComboは1から4に更新されるべき。
      for (var i = 0; i < 4; i++) {
        await service.solvePuzzle(
          sessionId: session.id,
          puzzleId: 'streak$i',
          puzzleDifficulty: 1,
          isCorrect: true,
          solveTime: 5,
        );
      }

      final doc = await firestore
          .collection('puzzleRushSessions')
          .doc(session.id)
          .get();
      expect(PuzzleRushRecord.fromJson(doc.data()!).maxCombo, 4);
    });

    test('endPuzzleRush with a displayName creates a leaderboard entry '
        'carrying it (regression: leaderboard previously had no '
        'displayName field at all)', () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );

      await service.endPuzzleRush(
        sessionId: session.id,
        displayName: 'Alice',
      );

      final leaderboard = await service.getLeaderboard(difficulty: 'easy');
      expect(leaderboard, hasLength(1));
      expect(leaderboard.single.displayName, 'Alice');
      expect(leaderboard.single.uid, 'u1');
    });

    test('endPuzzleRush with no displayName leaves it null (screen falls '
        'back to the uid fragment)', () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: session.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );

      await service.endPuzzleRush(sessionId: session.id);

      final leaderboard = await service.getLeaderboard(difficulty: 'easy');
      expect(leaderboard.single.displayName, isNull);
    });

    test('a later session with a higher score updates the existing entry\'s '
        'displayName too', () async {
      final session1 =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: session1.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: session1.id, displayName: 'Old');

      final session2 =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      for (var i = 0; i < 3; i++) {
        await service.solvePuzzle(
          sessionId: session2.id,
          puzzleId: 'p$i',
          puzzleDifficulty: 1,
          isCorrect: true,
          solveTime: 5,
        );
      }
      await service.endPuzzleRush(sessionId: session2.id, displayName: 'New');

      final leaderboard = await service.getLeaderboard(difficulty: 'easy');
      expect(leaderboard, hasLength(1));
      expect(leaderboard.single.displayName, 'New');
      expect(leaderboard.single.score, 30);
    });

    test('a later session with a lower score does not overwrite the '
        'existing higher-score entry', () async {
      final session1 =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      for (var i = 0; i < 3; i++) {
        await service.solvePuzzle(
          sessionId: session1.id,
          puzzleId: 'p$i',
          puzzleDifficulty: 1,
          isCorrect: true,
          solveTime: 5,
        );
      }
      await service.endPuzzleRush(sessionId: session1.id, displayName: 'Alice');

      final session2 =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: session2.id,
        puzzleId: 'p-low',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: session2.id, displayName: 'Alice2');

      final leaderboard = await service.getLeaderboard(difficulty: 'easy');
      expect(leaderboard.single.score, 30);
      expect(leaderboard.single.displayName, 'Alice');
    });

    test('getLeaderboard only returns entries for the requested difficulty',
        () async {
      final easy = await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: easy.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: easy.id, displayName: 'Alice');

      final hard = await service.startPuzzleRush(uid: 'u2', difficulty: 'hard');
      await service.solvePuzzle(
        sessionId: hard.id,
        puzzleId: 'p1',
        puzzleDifficulty: 3,
        isCorrect: true,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: hard.id, displayName: 'Bob');

      final easyBoard = await service.getLeaderboard(difficulty: 'easy');
      expect(easyBoard.map((e) => e.uid), ['u1']);
    });

    test('getUserPuzzleRushStats aggregates across sessions', () async {
      final s1 = await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: s1.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: true,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: s1.id);

      final s2 = await service.startPuzzleRush(uid: 'u1', difficulty: 'easy');
      await service.solvePuzzle(
        sessionId: s2.id,
        puzzleId: 'p1',
        puzzleDifficulty: 1,
        isCorrect: false,
        solveTime: 5,
      );
      await service.endPuzzleRush(sessionId: s2.id);

      final stats = await service.getUserPuzzleRushStats(uid: 'u1');
      expect(stats.totalSessions, 2);
      expect(stats.totalSolved, 2);
      expect(stats.totalCorrect, 1);
      expect(stats.accuracy, '50.0');
    });

    test('PuzzleRushLeaderboardEntry.fromJson tolerates a pre-existing '
        'document with no displayName field at all', () {
      final entry = PuzzleRushLeaderboardEntry.fromJson({
        'uid': 'legacy-user',
        'difficulty': 'easy',
        'score': 10,
        'solvedCount': 1,
        'accuracy': '100.0',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(entry.displayName, isNull);
      expect(entry.uid, 'legacy-user');
    });

    test(
        'sequential solvePuzzle calls still accumulate correctly now that '
        'the read-modify-write happens inside a transaction (regression '
        'guard for the solvePuzzle -> runTransaction rewrite: fixes a '
        'read-then-write race where two near-simultaneous calls for the '
        'same session, e.g. a UI double-tap or a timeout retry whose '
        'original call actually succeeded, could both read the same stale '
        'score/solvedCount/correctCount/totalAttempts and have one '
        'increment silently clobbered by the other)', () async {
      final session =
          await service.startPuzzleRush(uid: 'u1', difficulty: 'normal');

      for (var i = 0; i < 3; i++) {
        await service.solvePuzzle(
          sessionId: session.id,
          puzzleId: 'p$i',
          puzzleDifficulty: 1,
          isCorrect: true,
          solveTime: 5,
        );
      }

      final doc = await firestore
          .collection('puzzleRushSessions')
          .doc(session.id)
          .get();
      final updated = PuzzleRushRecord.fromJson(doc.data()!);

      expect(updated.solvedCount, 3);
      expect(updated.correctCount, 3);
      expect(updated.totalAttempts, 3);
      expect(updated.score, 30);
      expect(updated.puzzleIds, ['p0', 'p1', 'p2']);
      expect(updated.maxCombo, 3);
    });
  });
}

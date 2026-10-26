import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../test_utils.dart';
import '../fixtures/test_data.dart';

/// 中断・再開機能 (ActiveAiGame) のプロバイダー層テスト。
///
/// game_provider_undo_test.dart と同じ理由で、AIGameScreenを経由せず
/// ProviderContainerを直接操作する - aiMoveProviderの実計算を走らせない。
void main() {
  group('Resume/continue active AI game', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          activeAiGameServiceProvider.overrideWithValue(
            ActiveAiGameService(firestore: firestore),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<void> flushMicrotasks() => Future.delayed(Duration.zero);

    test('starting a new game persists it as the user\'s active game', () async {
      container.read(startNewGameProvider)(boardSize: 9);
      await flushMicrotasks();

      final saved = await firestore
          .collection('active_ai_games')
          .doc(TestData.testUser.uid)
          .get();
      expect(saved.exists, isTrue);
      expect(saved.data()!['movesCount'], equals(0));
    });

    test('playing a move updates the persisted snapshot', () async {
      container.read(startNewGameProvider)(boardSize: 9);
      await flushMicrotasks();

      container.read(applyMoveProvider)(2, 2);
      await flushMicrotasks();

      final saved = await firestore
          .collection('active_ai_games')
          .doc(TestData.testUser.uid)
          .get();
      expect(saved.data()!['movesCount'], equals(1));
      expect(saved.data()!['isBlackTurn'], isFalse);
    });

    test('resumeActiveGameProvider restores the board, turn and move history', () {
      final game = ActiveAiGame(
        uid: TestData.testUser.uid,
        boardSize: 9,
        stones: (() {
          final s = List.generate(9, (_) => List.filled(9, 0));
          s[2][2] = 1;
          return s;
        })(),
        isBlackTurn: false,
        capturedBlack: 0,
        capturedWhite: 0,
        aiLevel: 7,
        movesCount: 1,
        consecutivePasses: 0,
        sgfMoves: '(;GM[1]FF[4]SZ[9];B[cc])',
      );

      container.read(resumeActiveGameProvider)(game);

      expect(container.read(gameBoardStateProvider).stones[2][2], equals(1));
      expect(container.read(gameBoardStateProvider).isBlackTurn, isFalse);
      expect(container.read(aiLevelProvider), equals(7));
      expect(container.read(movesCountProvider), equals(1));
      expect(container.read(moveHistoryProvider), hasLength(1));
      expect(container.read(moveHistoryProvider).first.player, equals('black'));
      expect(container.read(isGameActiveProvider), isTrue);
    });

    test('clearActiveAiGameProvider deletes the saved game', () async {
      container.read(startNewGameProvider)(boardSize: 9);
      await flushMicrotasks();

      container.read(clearActiveAiGameProvider)();
      await flushMicrotasks();

      final saved = await firestore
          .collection('active_ai_games')
          .doc(TestData.testUser.uid)
          .get();
      expect(saved.exists, isFalse);
    });

    test('with no signed-in user, nothing is ever written', () async {
      final noUserContainer = TestUtils.createTestContainer(
        currentUser: null,
        extraOverrides: [
          activeAiGameServiceProvider.overrideWithValue(
            ActiveAiGameService(firestore: firestore),
          ),
        ],
      );
      addTearDown(noUserContainer.dispose);

      noUserContainer.read(startNewGameProvider)(boardSize: 9);
      await flushMicrotasks();

      final snapshot = await firestore.collection('active_ai_games').get();
      expect(snapshot.docs, isEmpty);
    });
  });
}

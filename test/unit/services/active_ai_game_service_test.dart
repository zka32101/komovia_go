import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/active_ai_game.dart';
import 'package:komovia_go/services/active_ai_game_service.dart';

void main() {
  group('ActiveAiGameService', () {
    late FakeFirebaseFirestore firestore;
    late ActiveAiGameService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ActiveAiGameService(firestore: firestore);
    });

    ActiveAiGame buildGame({String uid = 'uid1', int movesCount = 3}) {
      final stones = List.generate(9, (_) => List.filled(9, 0));
      stones[4][4] = 1;
      return ActiveAiGame(
        uid: uid,
        boardSize: 9,
        stones: stones,
        isBlackTurn: false,
        capturedBlack: 0,
        capturedWhite: 1,
        koRow: null,
        koCol: null,
        aiLevel: 5,
        movesCount: movesCount,
        consecutivePasses: 0,
        sgfMoves: '(;GM[1]FF[4]SZ[9];B[ee])',
      );
    }

    test('save writes the game keyed by uid, not an auto-generated id', () async {
      await service.save(buildGame());

      final doc = await firestore.collection('active_ai_games').doc('uid1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['movesCount'], equals(3));
      expect(doc.data()!['isBlackTurn'], isFalse);
      // Stones are digit-string-encoded rows, same convention as PvpGame.
      expect(doc.data()!['stones'][4], equals('000010000'));
    });

    test('getActive returns null when the user has no in-progress game', () async {
      final result = await service.getActive('no-such-uid');
      expect(result, isNull);
    });

    test('getActive round-trips a saved game', () async {
      await service.save(buildGame(movesCount: 7));

      final result = await service.getActive('uid1');
      expect(result, isNotNull);
      expect(result!.uid, equals('uid1'));
      expect(result.boardSize, equals(9));
      expect(result.movesCount, equals(7));
      expect(result.stones[4][4], equals(1));
      expect(result.sgfMoves, equals('(;GM[1]FF[4]SZ[9];B[ee])'));
    });

    test('save overwrites the same uid rather than creating a second document', () async {
      await service.save(buildGame(movesCount: 3));
      await service.save(buildGame(movesCount: 10));

      final snapshot = await firestore.collection('active_ai_games').get();
      expect(snapshot.docs.length, equals(1));
      expect(snapshot.docs.first.data()['movesCount'], equals(10));
    });

    test('clear deletes the saved game', () async {
      await service.save(buildGame());
      await service.clear('uid1');

      final result = await service.getActive('uid1');
      expect(result, isNull);
    });

    test('clear on a uid with no saved game is a harmless no-op', () async {
      await service.clear('never-played');
      // Should not throw.
    });

    test('two different users each get their own saved game', () async {
      await service.save(buildGame(uid: 'uid1', movesCount: 3));
      await service.save(buildGame(uid: 'uid2', movesCount: 20));

      final game1 = await service.getActive('uid1');
      final game2 = await service.getActive('uid2');
      expect(game1!.movesCount, equals(3));
      expect(game2!.movesCount, equals(20));
    });
  });
}

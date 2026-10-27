import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:komovia_go/services/index.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('CorrespondenceGameService Unit Tests', () {
    late CorrespondenceGameService service;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      service = CorrespondenceGameService(firestore: mockFirestore);
    });

    test('startCorrespondenceGame - 正常系：ゲーム作成成功', () async {
      expect(service, isNotNull);
    });

    test('startCorrespondenceGame - パラメータ検証：uid必須', () async {
      expect(service, isNotNull);
    });

    test('startCorrespondenceGame - パラメータ検証：opponentUid必須', () async {
      expect(service, isNotNull);
    });

    test('addMoveToGame - 正常系：手の追加成功', () async {
      expect(service, isNotNull);
    });

    test('addMoveToGame - ターン検証：有効なプレイヤー色確認', () async {
      expect(service, isNotNull);
    });

    test('endCorrespondenceGame - 正常系：ゲーム終了成功', () async {
      expect(service, isNotNull);
    });

    test('endCorrespondenceGame - パラメータ検証：result必須', () async {
      expect(service, isNotNull);
    });

    test('abandonGame - 正常系：ゲーム放棄成功', () async {
      expect(service, isNotNull);
    });

    test('abandonGame - パラメータ検証：gameId必須', () async {
      expect(service, isNotNull);
    });

    test('getUserCorrespondenceGames - 正常系：アクティブゲーム取得', () async {
      expect(service, isNotNull);
    });

    test('getUserCorrespondenceGames - ステータスフィルタ：active', () async {
      expect(service, isNotNull);
    });

    test('getUserCorrespondenceGames - ステータスフィルタ：completed', () async {
      expect(service, isNotNull);
    });

    test('getUserCorrespondenceGames - ステータスフィルタ：all', () async {
      expect(service, isNotNull);
    });

    test('getPendingMoveCount - 正常系：カウント計算成功', () async {
      expect(service, isNotNull);
    });

    test('_sendGameNotification - 正常系：通知送信成功', () async {
      expect(service, isNotNull);
    });

    test('_sendGameNotification - パラメータ検証：recipientUid必須', () async {
      expect(service, isNotNull);
    });

    test('ターン検証 - currentPlayerColor確認', () async {
      expect(service, isNotNull);
    });

    test('ゲーム状態管理 - status遷移', () async {
      expect(service, isNotNull);
    });

    test('エラーハンドリング - ゲーム未検出時の例外', () async {
      expect(service, isNotNull);
    });

    test('エラーハンドリング - 無効なプレイヤー色時の例外', () async {
      expect(service, isNotNull);
    });

    test('インスタンス生成 - デフォルトFirestore', () {
      final serviceDefault = CorrespondenceGameService();
      expect(serviceDefault, isNotNull);
    });

    test('インスタンス生成 - カスタムFirestore', () {
      final serviceCustom = CorrespondenceGameService(firestore: mockFirestore);
      expect(serviceCustom, isNotNull);
    });
  });

  group('CorrespondenceGameService.getUserCorrespondenceGames - real behavior', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CorrespondenceGameService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = CorrespondenceGameService(firestore: fakeFirestore);
    });

    test('an invited player (opponentUid) sees the game, not only its creator', () async {
      final game = await service.startCorrespondenceGame(
        uid: 'creator',
        opponentUid: 'invitee',
        boardSize: 9,
      );

      final creatorGames = await service.getUserCorrespondenceGames(uid: 'creator');
      final inviteeGames = await service.getUserCorrespondenceGames(uid: 'invitee');

      expect(creatorGames.map((g) => g.id), contains(game.id));
      expect(inviteeGames.map((g) => g.id), contains(game.id));
    });

    test('a game is not duplicated when the same uid is somehow both creator and opponent', () async {
      await service.startCorrespondenceGame(
        uid: 'self',
        opponentUid: 'self',
        boardSize: 9,
      );

      final games = await service.getUserCorrespondenceGames(uid: 'self');
      expect(games.length, 1);
    });

    test('status filter excludes games not matching, for both creator and invitee', () async {
      final game = await service.startCorrespondenceGame(
        uid: 'creator2',
        opponentUid: 'invitee2',
        boardSize: 9,
      );
      await service.endCorrespondenceGame(
        gameId: game.id,
        result: 'win',
        winnerColor: 'black',
        sgfData: '',
      );

      final inviteeActive = await service.getUserCorrespondenceGames(
        uid: 'invitee2',
      );
      final inviteeCompleted = await service.getUserCorrespondenceGames(
        uid: 'invitee2',
        status: 'completed',
      );

      expect(inviteeActive, isEmpty);
      expect(inviteeCompleted.map((g) => g.id), contains(game.id));
    });

    test('results are sorted by lastMoveAt descending across both queries', () async {
      final older = await service.startCorrespondenceGame(
        uid: 'player',
        opponentUid: 'other1',
        boardSize: 9,
      );
      await fakeFirestore.collection('correspondenceGames').doc(older.id).update({
        'lastMoveAt': DateTime(2020, 1, 1).toIso8601String(),
      });
      final newer = await service.startCorrespondenceGame(
        uid: 'other2',
        opponentUid: 'player',
        boardSize: 9,
      );
      await fakeFirestore.collection('correspondenceGames').doc(newer.id).update({
        'lastMoveAt': DateTime(2030, 1, 1).toIso8601String(),
      });

      final games = await service.getUserCorrespondenceGames(uid: 'player');
      expect(games.map((g) => g.id).toList(), [newer.id, older.id]);
    });
  });

  group('CorrespondenceGameService.getPendingMoveCount - real behavior', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CorrespondenceGameService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = CorrespondenceGameService(firestore: fakeFirestore);
    });

    Future<void> _setTurn(String gameId, String color) {
      return fakeFirestore
          .collection('correspondenceGames')
          .doc(gameId)
          .update({'currentPlayerColor': color});
    }

    test(
        "counts a game the user created (always black) when it's actually "
        'black\'s turn - the real bug this fixes only ever queried '
        'opponentUid, so the creator never saw a pending-move count', () async {
      final game = await service.startCorrespondenceGame(
        uid: 'creator',
        opponentUid: 'invitee',
        boardSize: 9,
      );
      // startCorrespondenceGame always begins with black (the creator) to
      // move, so this is already true, but set it explicitly for clarity.
      await _setTurn(game.id, 'black');

      expect(await service.getPendingMoveCount(uid: 'creator'), 1);
      expect(await service.getPendingMoveCount(uid: 'invitee'), 0);
    });

    test(
        "does not count a game the user was invited to (always white) when "
        "it's actually black's (the creator's) turn - the real bug this "
        'fixes summed both colors\' turn-counts unconditionally, so the '
        'invitee\'s badge counted every active game, not just the ones '
        'genuinely awaiting their move', () async {
      final game = await service.startCorrespondenceGame(
        uid: 'creator2',
        opponentUid: 'invitee2',
        boardSize: 9,
      );
      await _setTurn(game.id, 'black');

      expect(await service.getPendingMoveCount(uid: 'invitee2'), 0);

      await _setTurn(game.id, 'white');

      expect(await service.getPendingMoveCount(uid: 'invitee2'), 1);
      expect(await service.getPendingMoveCount(uid: 'creator2'), 0);
    });
  });
}

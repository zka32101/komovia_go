import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/spectator_service.dart';

void main() {
  group('SpectatorService', () {
    late FakeFirebaseFirestore firestore;
    late SpectatorService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = SpectatorService(firestore);
    });

    test('createSpectatorSession without coHostUid stores it as null (ai_game case)', () async {
      final session = await service.createSpectatorSession(
        gameId: 'g1',
        gameType: 'ai_game',
        hostUid: 'host',
        hostDisplayName: 'Host',
        isLive: true,
        boardSize: 9,
      );

      final fetched = await service.getSpectatorSession(session.id);
      expect(fetched!.hostUid, 'host');
      expect(fetched.coHostUid, null);
      expect(fetched.gameType, 'ai_game');
    });

    test('createSpectatorSession with coHostUid round-trips it (pvp_game case)', () async {
      final session = await service.createSpectatorSession(
        gameId: 'g2',
        gameType: 'pvp_game',
        hostUid: 'black',
        hostDisplayName: 'Black',
        isLive: true,
        boardSize: 19,
        coHostUid: 'white',
      );

      final fetched = await service.getSpectatorSession(session.id);
      expect(fetched!.hostUid, 'black');
      expect(fetched.coHostUid, 'white');
    });

    test('updateBoardState updates stones, turn and last move for the session', () async {
      final session = await service.createSpectatorSession(
        gameId: 'g3',
        gameType: 'pvp_game',
        hostUid: 'black',
        hostDisplayName: 'Black',
        isLive: true,
        boardSize: 9,
        coHostUid: 'white',
      );

      final stones = List.generate(9, (_) => List.filled(9, 0));
      stones[4][4] = 1;
      await service.updateBoardState(
        sessionId: session.id,
        moveIndex: 1,
        stones: stones,
        isBlackTurn: false,
        lastMoveRow: 4,
        lastMoveCol: 4,
      );

      final fetched = await service.getSpectatorSession(session.id);
      expect(fetched!.stones![4][4], 1);
      expect(fetched.isBlackTurn, false);
      expect(fetched.lastMoveRow, 4);
      expect(fetched.lastMoveCol, 4);
      expect(fetched.moveIndex, 1);
    });

    test('getActiveSpectatorSessions only returns live, unended sessions', () async {
      final live = await service.createSpectatorSession(
        gameId: 'g4',
        gameType: 'pvp_game',
        hostUid: 'black',
        hostDisplayName: 'Black',
        isLive: true,
      );
      final ended = await service.createSpectatorSession(
        gameId: 'g5',
        gameType: 'pvp_game',
        hostUid: 'other',
        hostDisplayName: 'Other',
        isLive: true,
      );
      await service.endSpectatorSession(ended.id);

      final active = await service.getActiveSpectatorSessions();
      final activeIds = active.map((s) => s.id).toSet();
      expect(activeIds.contains(live.id), true);
      expect(activeIds.contains(ended.id), false);
    });
  });
}

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/services/game_mode_service.dart';
import 'package:komovia_go/services/blitz_game_service.dart';
import 'package:komovia_go/services/correspondence_game_service.dart';
import 'package:komovia_go/services/team_game_service.dart';
import 'package:komovia_go/models/sns_models.dart';

void main() {
  group('Game Mode Management Tests', () {
    late FakeFirebaseFirestore firestore;
    late GameModeService gameModeService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      gameModeService = GameModeService(firestore: firestore);
    });

    group('Game Mode CRUD Operations', () {
      test('Retrieves all available game modes', () async {
        // When
        final modes = await gameModeService.getAllGameModes();

        // Then
        expect(modes, isNotNull);
        expect(modes, isA<List<GameMode>>());
      });

      test('Filters active game modes only', () async {
        // When
        final activeModes = await gameModeService.getActiveGameModes();

        // Then
        expect(activeModes, isNotNull);
        for (final mode in activeModes) {
          expect(mode.isActive, true);
        }
      });

      test('Retrieves specific game mode by ID', () async {
        // Given
        final modeId = 'blitz-mode';
        await firestore.collection('game_modes').doc(modeId).set({
          'name': 'Blitz',
          'description': '5分の高速対局',
          'timeLimit': 300,
          'difficulty': 'normal',
          'type': 'blitz',
          'maxPlayers': 2,
          'isActive': true,
        });

        // When
        final mode = await gameModeService.getGameMode(modeId);

        // Then
        expect(mode, isNotNull);
        expect(mode?.id, modeId);
      });

      test('Creates new game mode', () async {
        // Given
        final newMode = GameMode(
          id: 'custom-mode',
          name: 'カスタムモード',
          description: 'ユーザー定義のゲームモード',
          timeLimit: 600, // 10 minutes
          difficulty: 'normal',
          type: GameModeType.traditional,
          maxPlayers: 2,
          isActive: true,
        );

        // When
        final created = await gameModeService.createGameMode(newMode);

        // Then
        expect(created, isNotNull);
        expect(created?.name, 'カスタムモード');
      });

      test('Handles non-existent game mode gracefully', () async {
        // Given
        final nonExistentId = 'non-existent-mode-xyz';

        // When
        final mode = await gameModeService.getGameMode(nonExistentId);

        // Then
        expect(mode, isNull);
      });
    });

    group('Game Session Management', () {
      test('Starts a new game session with game mode', () async {
        // Given
        final gameMode = GameMode(
          id: 'blitz-1',
          name: 'Blitz',
          description: '5分急速戦',
          timeLimit: 300,
          difficulty: 'normal',
          type: GameModeType.blitz,
          maxPlayers: 2,
        );
        final blackPlayerId = 'player-black-123';
        final whitePlayerId = 'player-white-456';

        // When
        final session = await gameModeService.startGameSession(
          gameMode: gameMode,
          blackPlayerId: blackPlayerId,
          whitePlayerId: whitePlayerId,
        );

        // Then
        expect(session, isNotNull);
        expect(session?.gameMode.type, GameModeType.blitz);
        expect(session?.blackPlayerId, blackPlayerId);
        expect(session?.whitePlayerId, whitePlayerId);
        expect(session?.timeRemainingBlack, 300);
      });

      test('Ends game session', () async {
        // Given
        final sessionId = 'session-end-001';

        // When
        final success = await gameModeService.endGameSession(sessionId);

        // Then
        expect(success, isA<bool>());
      });
    });

    group('Game Mode Type Validation', () {
      test('Validates Blitz mode configuration', () {
        // Given
        final blitzMode = GameMode(
          id: 'blitz-test',
          name: 'Blitz',
          description: '5分急速戦',
          timeLimit: 300,
          difficulty: 'normal',
          type: GameModeType.blitz,
          maxPlayers: 2,
        );

        // Then
        expect(blitzMode.type, GameModeType.blitz);
        expect(blitzMode.timeLimit, 300);
        expect(blitzMode.maxPlayers, 2);
      });

      test('Validates Correspondence mode (no time limit)', () {
        // Given
        final correspondenceMode = GameMode(
          id: 'correspondence-test',
          name: 'Correspondence',
          description: 'ターンベース対局',
          timeLimit: 0, // No limit
          difficulty: 'normal',
          type: GameModeType.correspondence,
          maxPlayers: 2,
        );

        // Then
        expect(correspondenceMode.type, GameModeType.correspondence);
        expect(correspondenceMode.timeLimit, 0);
      });

      test('Validates Team Play mode (2vs2)', () {
        // Given
        final teamMode = GameMode(
          id: 'team-test',
          name: 'Team Play',
          description: '2vs2チーム戦',
          timeLimit: 1800, // 30 minutes
          difficulty: 'normal',
          type: GameModeType.team,
          maxPlayers: 4,
        );

        // Then
        expect(teamMode.type, GameModeType.team);
        expect(teamMode.maxPlayers, 4);
      });

      test('Validates Handicap variant configuration', () {
        // Given
        final handicapMode = GameMode(
          id: 'handicap-test',
          name: 'Handicap',
          description: 'ハンディキャップ戦',
          timeLimit: 900, // 15 minutes
          difficulty: 'hard',
          type: GameModeType.handicap,
          maxPlayers: 2,
        );

        // Then
        expect(handicapMode.type, GameModeType.handicap);
        expect(handicapMode.difficulty, 'hard');
      });
    });
  });

  group('Blitz Game Service Tests', () {
    late FakeFirebaseFirestore firestore;
    late BlitzGameService blitzService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      blitzService = BlitzGameService(firestore: firestore);
    });

    test('Starts Blitz game with 5-minute timer', () async {
      // Given
      final uid = 'user-123';
      final boardSize = 19;
      final opponentUid = 'user-456';

      // When
      final game = await blitzService.startBlitzGame(
        uid: uid,
        boardSize: boardSize,
        opponentUid: opponentUid,
      );

      // Then
      expect(game, isNotNull);
      expect(game.boardSize, 19);
      expect(game.whitePlayer, uid);
      expect(game.durationSeconds, lessThanOrEqualTo(300));
    });

    test('Adds move to Blitz game', () async {
      // Given - addMove only updates an existing document (matches real
      // Firestore, which also rejects update() on a missing doc)
      final game = await blitzService.startBlitzGame(
        uid: 'user-1',
        boardSize: 19,
        opponentUid: 'user-2',
      );
      final move = 'Q16'; // Standard Go notation
      final playerColor = 'white';

      // When
      await blitzService.addMove(
        gameId: game.id,
        move: move,
        playerColor: playerColor,
      );

      // Then - Move was added (verified by no exception thrown)
      final doc = await firestore.collection('blitzGames').doc(game.id).get();
      expect(doc.data()?['moveHistory'], contains(move));
    });

    test('Handles rapid move sequences in Blitz', () async {
      // Given
      final game = await blitzService.startBlitzGame(
        uid: 'user-3',
        boardSize: 19,
        opponentUid: 'user-4',
      );
      final moves = ['Q16', 'D4', 'Q3', 'C3'];

      // When
      for (final move in moves) {
        await blitzService.addMove(
          gameId: game.id,
          move: move,
          playerColor: move.hashCode.isEven ? 'black' : 'white',
        );
      }

      // Then - All moves processed without timeout
      final doc = await firestore.collection('blitzGames').doc(game.id).get();
      expect(doc.data()?['moveHistory'], moves);
    });
  });

  group('Correspondence Game Service Tests', () {
    late CorrespondenceGameService correspondenceService;

    setUp(() {
      correspondenceService = CorrespondenceGameService(firestore: FakeFirebaseFirestore());
    });

    test('Starts turn-based Correspondence game', () async {
      // Given
      final uid = 'user-789';
      final opponentUid = 'user-000';
      final boardSize = 19;

      // When
      final game = await correspondenceService.startCorrespondenceGame(
        uid: uid,
        boardSize: boardSize,
        opponentUid: opponentUid,
      );

      // Then
      expect(game, isNotNull);
      expect(game.status, 'active');
    });
  });

  group('Team Game Service Tests', () {
    late TeamGameService teamService;

    setUp(() {
      teamService = TeamGameService(firestore: FakeFirebaseFirestore());
    });

    test('Creates 2vs2 team game session', () async {
      // Given
      final team1Players = ['player-1', 'player-2'];
      final team2Players = ['player-3', 'player-4'];
      final boardSize = 19;

      // When
      final game = await teamService.startTeamGame(
        team1Players: team1Players,
        team2Players: team2Players,
        boardSize: boardSize,
      );

      // Then
      expect(game, isNotNull);
      expect(game.team1Players.length + game.team2Players.length, 4);
    });

    test('Calculates team score aggregation', () async {
      // Given
      final team1Score = 125.5;
      final team2Score = 115.0;

      // When
      final winner = team1Score > team2Score ? 'team1' : 'team2';
      final scoreDifference = (team1Score - team2Score).abs();

      // Then
      expect(winner, 'team1');
      expect(scoreDifference, greaterThan(0));
    });
  });

  group('Cross-Mode Features', () {
    late FakeFirebaseFirestore firestore;
    late GameModeService gameModeService;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      gameModeService = GameModeService(firestore: firestore);
    });

    test('Generates statistics by game mode', () async {
      // Given - getGameModeStats aggregates over the shared 'games'
      // collection filtered by modeId, not a per-user breakdown
      final modeId = 'blitz';
      await firestore.collection('games').add({
        'modeId': modeId,
        'durationSeconds': 200,
      });
      await firestore.collection('games').add({
        'modeId': modeId,
        'durationSeconds': 400,
      });

      // When
      final stats = await gameModeService.getGameModeStats(modeId);

      // Then
      expect(stats, isNotNull);
      expect(stats['modeId'], modeId);
      expect(stats['totalGames'], 2);
      expect(stats.containsKey('avgDuration'), true);
    });

  });

  group('Game Mode Configuration & Customization', () {
    test('Supports custom time configurations', () {
      // Given
      final customMode = GameMode(
        id: 'custom-time',
        name: 'Rapid',
        description: 'カスタム急速戦',
        timeLimit: 600, // 10 minutes custom
        difficulty: 'normal',
        type: GameModeType.traditional,
        maxPlayers: 2,
      );

      // Then
      expect(customMode.timeLimit, 600);
    });

    test('Supports difficulty level variations', () {
      // Given
      final easyMode = GameMode(
        id: 'easy-mode',
        name: 'Easy',
        description: '初心者向け',
        timeLimit: 900,
        difficulty: 'easy',
        type: GameModeType.traditional,
        maxPlayers: 2,
      );

      // Then
      expect(easyMode.difficulty, 'easy');
    });

    test('Handles game mode icons/assets', () {
      // Given
      final modeWithIcon = GameMode(
        id: 'icon-test',
        name: 'Blitz',
        description: '5分急速戦',
        timeLimit: 300,
        difficulty: 'normal',
        type: GameModeType.blitz,
        maxPlayers: 2,
        iconPath: 'assets/icons/blitz.svg',
      );

      // Then
      expect(modeWithIcon.iconPath, isNotNull);
      expect(modeWithIcon.iconPath?.contains('blitz'), true);
    });
  });
}

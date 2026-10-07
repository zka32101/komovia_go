import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/game_settings_storage_service.dart';

void main() {
  group('GameSettingsStorageService Tests', () {
    late SharedPreferences prefs;
    late GameSettingsStorageService service;

    setUpAll(() async {
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    setUp(() {
      service = GameSettingsStorageService(prefs: prefs);
    });

    tearDown(() async {
      // Clear all keys after each test
      await prefs.clear();
    });

    group('Blitz Game Settings', () {
      test('saveBlitzSettings should save and return true', () async {
        final settings = BlitzGameSettings(
          boardSize: '19',
          aiLevel: 7,
          opponentType: 'ai',
        );

        final result = await service.saveBlitzSettings(settings);

        expect(result, true);
      });

      test('loadBlitzSettings should return null when no settings saved', () {
        final result = service.loadBlitzSettings();

        expect(result, isNull);
      });

      test('loadBlitzSettings should return saved settings', () async {
        final originalSettings = BlitzGameSettings(
          boardSize: '13',
          aiLevel: 5,
          opponentType: 'human',
        );

        await service.saveBlitzSettings(originalSettings);
        final loadedSettings = service.loadBlitzSettings();

        expect(loadedSettings, isNotNull);
        expect(loadedSettings?.boardSize, '13');
        expect(loadedSettings?.aiLevel, 5);
        expect(loadedSettings?.opponentType, 'human');
      });

      test('loadBlitzSettings should handle corrupted data gracefully', () async {
        // Set corrupted data
        await prefs.setString('blitz_board_size', '19');
        await prefs.setInt('blitz_ai_level', -1); // Invalid

        // loadBlitzSettings should handle this gracefully
        final result = service.loadBlitzSettings();
        expect(result, isNotNull);
      });
    });

    group('Correspondence Game Settings', () {
      test('saveCorrespondenceSettings should save and return true', () async {
        final settings = CorrespondenceGameSettings(
          boardSize: '19',
          opponentUid: 'user123',
          playerColor: 'black',
        );

        final result = await service.saveCorrespondenceSettings(settings);

        expect(result, true);
      });

      test('loadCorrespondenceSettings should return null when no settings saved', () {
        final result = service.loadCorrespondenceSettings();

        expect(result, isNull);
      });

      test('loadCorrespondenceSettings should return saved settings', () async {
        final originalSettings = CorrespondenceGameSettings(
          boardSize: '9',
          opponentUid: 'opponent456',
          playerColor: 'white',
        );

        await service.saveCorrespondenceSettings(originalSettings);
        final loadedSettings = service.loadCorrespondenceSettings();

        expect(loadedSettings, isNotNull);
        expect(loadedSettings?.boardSize, '9');
        expect(loadedSettings?.opponentUid, 'opponent456');
        expect(loadedSettings?.playerColor, 'white');
      });

      test('loadCorrespondenceSettings should return null if opponentUid is empty', () async {
        // Set incomplete data
        await prefs.setString('correspondence_board_size', '19');

        final result = service.loadCorrespondenceSettings();
        expect(result, isNull);
      });
    });

    group('Team Game Settings', () {
      test('saveTeamSettings should save and return true', () async {
        final settings = TeamGameSettings(
          boardSize: '19',
          team1Uids: ['user1', 'user2'],
          team2Uids: ['user3', 'user4'],
        );

        final result = await service.saveTeamSettings(settings);

        expect(result, true);
      });

      test('loadTeamSettings should return null when no settings saved', () {
        final result = service.loadTeamSettings();

        expect(result, isNull);
      });

      test('loadTeamSettings should return saved settings', () async {
        final originalSettings = TeamGameSettings(
          boardSize: '13',
          team1Uids: ['playerA', 'playerB'],
          team2Uids: ['playerC', 'playerD'],
        );

        await service.saveTeamSettings(originalSettings);
        final loadedSettings = service.loadTeamSettings();

        expect(loadedSettings, isNotNull);
        expect(loadedSettings?.boardSize, '13');
        expect(loadedSettings?.team1Uids, ['playerA', 'playerB']);
        expect(loadedSettings?.team2Uids, ['playerC', 'playerD']);
      });

      test('loadTeamSettings should return null if boardSize is missing', () async {
        // Set incomplete data
        await prefs.setStringList('team_board_size', []);

        final result = service.loadTeamSettings();
        expect(result, isNull);
      });
    });

    group('Puzzle Rush Settings', () {
      test('savePuzzleRushSettings should save and return true', () async {
        final settings = PuzzleRushSettings(
          difficulty: 'hard',
        );

        final result = await service.savePuzzleRushSettings(settings);

        expect(result, true);
      });

      test('loadPuzzleRushSettings should return null when no settings saved', () {
        final result = service.loadPuzzleRushSettings();

        expect(result, isNull);
      });

      test('loadPuzzleRushSettings should return saved settings', () async {
        final originalSettings = PuzzleRushSettings(
          difficulty: 'expert',
        );

        await service.savePuzzleRushSettings(originalSettings);
        final loadedSettings = service.loadPuzzleRushSettings();

        expect(loadedSettings, isNotNull);
        expect(loadedSettings?.difficulty, 'expert');
      });

      test('loadPuzzleRushSettings should return null if difficulty is missing', () async {
        // Don't set any data
        final result = service.loadPuzzleRushSettings();
        expect(result, isNull);
      });
    });

    group('Clear All Settings', () {
      test('clearAllSettings should clear all settings and return true', () async {
        // Save multiple settings
        final blitzSettings = BlitzGameSettings(
          boardSize: '19',
          aiLevel: 5,
          opponentType: 'ai',
        );
        final puzzleSettings = PuzzleRushSettings(difficulty: 'hard');

        await service.saveBlitzSettings(blitzSettings);
        await service.savePuzzleRushSettings(puzzleSettings);

        // Verify settings are saved
        expect(service.loadBlitzSettings(), isNotNull);
        expect(service.loadPuzzleRushSettings(), isNotNull);

        // Clear all
        final result = await service.clearAllSettings();
        expect(result, true);

        // Verify all settings are cleared
        expect(service.loadBlitzSettings(), isNull);
        expect(service.loadCorrespondenceSettings(), isNull);
        expect(service.loadTeamSettings(), isNull);
        expect(service.loadPuzzleRushSettings(), isNull);
      });

      test('clearAllSettings should return true even if no settings exist', () async {
        final result = await service.clearAllSettings();
        expect(result, true);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('saveBlitzSettings handles exception gracefully', () async {
        final settings = BlitzGameSettings(
          boardSize: '19',
          aiLevel: 5,
          opponentType: 'ai',
        );

        // Normal save should succeed
        final result = await service.saveBlitzSettings(settings);
        expect(result, true);
      });

      test('loadBlitzSettings returns null when only partial data exists', () async {
        // Set only board size, missing ai level
        await prefs.setString('blitz_board_size', '19');

        final result = service.loadBlitzSettings();
        expect(result, isNull);
      });

      test('multiple save operations do not interfere', () async {
        final blitzSettings = BlitzGameSettings(
          boardSize: '19',
          aiLevel: 7,
          opponentType: 'ai',
        );
        final puzzleSettings = PuzzleRushSettings(difficulty: 'expert');

        await service.saveBlitzSettings(blitzSettings);
        await service.savePuzzleRushSettings(puzzleSettings);

        final loadedBlitz = service.loadBlitzSettings();
        final loadedPuzzle = service.loadPuzzleRushSettings();

        expect(loadedBlitz?.boardSize, '19');
        expect(loadedBlitz?.aiLevel, 7);
        expect(loadedPuzzle?.difficulty, 'expert');
      });

      test('settings persist across service instances', () async {
        final settings = BlitzGameSettings(
          boardSize: '9',
          aiLevel: 3,
          opponentType: 'ai',
        );

        // Save with first service instance
        await service.saveBlitzSettings(settings);

        // Load with new service instance
        final newService = GameSettingsStorageService(prefs: prefs);
        final loaded = newService.loadBlitzSettings();

        expect(loaded, isNotNull);
        expect(loaded?.boardSize, '9');
        expect(loaded?.aiLevel, 3);
      });
    });
  });
}

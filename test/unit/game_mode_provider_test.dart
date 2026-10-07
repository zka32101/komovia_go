import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

void main() {
  group('GameModeProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    /// Test 1: selectedGameModeProvider starts with null
    test('selectedGameModeProvider initial state is null', () {
      final selectedMode = container.read(selectedGameModeProvider);
      expect(selectedMode, isNull);
    });

    /// Test 2: selectedGameModeProvider can be set
    test('selectedGameModeProvider can be set', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      container.read(selectedGameModeProvider.notifier).state = testMode;

      final selectedMode = container.read(selectedGameModeProvider);
      expect(selectedMode, equals(testMode));
      expect(selectedMode!.id, equals('test_1'));
      expect(selectedMode.name, equals('テストモード'));
    });

    /// Test 3: gameModeUIProvider initial state
    test('gameModeUIProvider initial state', () {
      final uiState = container.read(gameModeUIProvider);

      expect(uiState.isLoading, isFalse);
      expect(uiState.error, isNull);
      expect(uiState.selectedMode, isNull);
    });

    /// Test 4: GameModeUINotifier setLoading updates state
    test('GameModeUINotifier setLoading updates state', () {
      container.read(gameModeUIProvider.notifier).setLoading(true);

      final uiState = container.read(gameModeUIProvider);
      expect(uiState.isLoading, isTrue);
      expect(uiState.error, isNull);
    });

    /// Test 5: GameModeUINotifier setError updates state
    test('GameModeUINotifier setError updates state', () {
      container.read(gameModeUIProvider.notifier).setError('テストエラー');

      final uiState = container.read(gameModeUIProvider);
      expect(uiState.error, equals('テストエラー'));
      expect(uiState.isLoading, isFalse);
    });

    /// Test 6: GameModeUINotifier selectMode updates state
    test('GameModeUINotifier selectMode updates state', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      container.read(gameModeUIProvider.notifier).selectMode(testMode);

      final uiState = container.read(gameModeUIProvider);
      expect(uiState.selectedMode, equals(testMode));
      expect(uiState.error, isNull);
    });

    /// Test 7: GameModeUINotifier clearSelection clears state
    test('GameModeUINotifier clearSelection clears state', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      container.read(gameModeUIProvider.notifier).selectMode(testMode);
      container.read(gameModeUIProvider.notifier).clearSelection();

      final uiState = container.read(gameModeUIProvider);
      expect(uiState.selectedMode, isNull);
      expect(uiState.error, isNull);
    });

    /// Test 8: GameModeUIState copyWith creates new instance
    test('GameModeUIState copyWith creates new instance', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      final state1 = GameModeUIState(isLoading: true);
      final state2 = state1.copyWith(isLoading: false, selectedMode: testMode);

      expect(state1.isLoading, isTrue);
      expect(state2.isLoading, isFalse);
      expect(state2.selectedMode, equals(testMode));
    });

    /// Test 9: selectGameModeProvider callback works
    test('selectGameModeProvider callback selects mode', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      final selectCallback = container.read(selectGameModeProvider);
      selectCallback(testMode);

      final selectedMode = container.read(selectedGameModeProvider);
      expect(selectedMode, equals(testMode));
    });

    /// Test 10: clearGameModeProvider callback clears selection
    test('clearGameModeProvider callback clears selection', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      // First select a mode
      container.read(selectedGameModeProvider.notifier).state = testMode;
      expect(container.read(selectedGameModeProvider), isNotNull);

      // Then clear it
      final clearCallback = container.read(clearGameModeProvider);
      clearCallback();

      expect(container.read(selectedGameModeProvider), isNull);
    });

    /// Test 11: Multiple mode selections update correctly
    test('multiple mode selections update correctly', () {
      final mode1 = GameMode(
        id: 'blitz_1',
        name: 'ブリッツ',
        description: '高速対局',
        timeLimit: 300,
        difficulty: 'medium',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      final mode2 = GameMode(
        id: 'team_1',
        name: 'チーム戦',
        description: 'チーム対局',
        timeLimit: 0,
        difficulty: 'hard',
        type: GameModeType.team,
        maxPlayers: 4,
        isActive: true,
      );

      // Select first mode
      container.read(selectedGameModeProvider.notifier).state = mode1;
      expect(container.read(selectedGameModeProvider)!.id, equals('blitz_1'));

      // Select second mode
      container.read(selectedGameModeProvider.notifier).state = mode2;
      expect(container.read(selectedGameModeProvider)!.id, equals('team_1'));

      // Verify type changed
      expect(
        container.read(selectedGameModeProvider)!.type,
        equals(GameModeType.team),
      );
    });

    /// Test 12: GameModeUIState preserves unmodified fields
    test('GameModeUIState copyWith preserves unmodified fields', () {
      final testMode = GameMode(
        id: 'test_1',
        name: 'テストモード',
        description: 'テスト用',
        timeLimit: 600,
        difficulty: 'easy',
        type: GameModeType.blitz,
        maxPlayers: 2,
        isActive: true,
      );

      final state1 = GameModeUIState(
        isLoading: true,
        error: 'テストエラー',
        selectedMode: testMode,
      );

      final state2 = state1.copyWith(isLoading: false);

      expect(state2.isLoading, isFalse);
      expect(state2.error, equals('テストエラー')); // Preserved
      expect(state2.selectedMode, equals(testMode)); // Preserved
    });
  });
}

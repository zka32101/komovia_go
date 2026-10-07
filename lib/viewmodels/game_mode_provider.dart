import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

final _logger = Logger();

// ================== SERVICE PROVIDERS ==================

/// Singleton instance of GameModeService
final gameModeServiceProvider = Provider<GameModeService>((ref) {
  return GameModeService();
});

// ================== GAME MODE STATE PROVIDERS ==================

/// Current selected game mode
final selectedGameModeProvider = StateProvider<GameMode?>((ref) {
  return null;
});

/// All available game modes
final allGameModesProvider = FutureProvider<List<GameMode>>((ref) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.d('Loading all game modes...');
    final modes = await service.getAllGameModes();
    _logger.i('Loaded ${modes.length} game modes');
    return modes;
  } catch (e) {
    _logger.e('Error loading game modes: $e');
    rethrow;
  }
});

/// Active game modes only (for UI selection)
final activeGameModesProvider = FutureProvider<List<GameMode>>((ref) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.d('Loading active game modes...');
    final modes = await service.getActiveGameModes();
    _logger.i('Loaded ${modes.length} active game modes');
    return modes;
  } catch (e) {
    _logger.e('Error loading active game modes: $e');
    rethrow;
  }
});

/// Specific game mode by ID
final gameModeByIdProvider =
    FutureProvider.family<GameMode?, String>((ref, modeId) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.d('Loading game mode: $modeId');
    final mode = await service.getGameMode(modeId);
    if (mode != null) {
      _logger.i('Loaded game mode: ${mode.name}');
    } else {
      _logger.w('Game mode not found: $modeId');
    }
    return mode;
  } catch (e) {
    _logger.e('Error loading game mode $modeId: $e');
    rethrow;
  }
});

/// Game modes filtered by difficulty
final gameModesByDifficultyProvider =
    FutureProvider.family<List<GameMode>, String>((ref, difficulty) async {
  try {
    final modes = await ref.watch(activeGameModesProvider.future);
    return modes.where((mode) => mode.difficulty == difficulty).toList();
  } catch (e) {
    _logger.e('Error loading game modes by difficulty: $e');
    rethrow;
  }
});

/// Game modes filtered by type
final gameModesByTypeProvider =
    FutureProvider.family<List<GameMode>, GameModeType>((ref, type) async {
  try {
    final modes = await ref.watch(activeGameModesProvider.future);
    return modes.where((mode) => mode.type == type).toList();
  } catch (e) {
    _logger.e('Error loading game modes by type: $e');
    rethrow;
  }
});

// ================== ACTION PROVIDERS ==================

/// Select a game mode and navigate to it
final selectGameModeProvider = Provider<void Function(GameMode mode)>((ref) {
  return (GameMode mode) {
    _logger.i('Selected game mode: ${mode.name} (${mode.type})');
    ref.read(selectedGameModeProvider.notifier).state = mode;

    // Update game settings based on mode
    if (mode.timeLimit > 0) {
      _logger.d('Setting time limit: ${mode.timeLimit}s');
    }
  };
});

/// Clear the current game mode selection
final clearGameModeProvider = Provider<void Function()>((ref) {
  return () {
    _logger.d('Clearing game mode selection');
    ref.read(selectedGameModeProvider.notifier).state = null;
  };
});

/// Create a new game mode (admin only)
final createGameModeProvider =
    FutureProvider.family<GameMode?, GameMode>((ref, mode) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.i('Creating game mode: ${mode.name}');
    final created = await service.createGameMode(mode);
    if (created != null) {
      _logger.i('Game mode created successfully: ${created.id}');
      // Invalidate the list to refresh
      ref.invalidate(allGameModesProvider);
      ref.invalidate(activeGameModesProvider);
    }
    return created;
  } catch (e) {
    _logger.e('Error creating game mode: $e');
    rethrow;
  }
});

/// Update an existing game mode (admin only)
final updateGameModeProvider =
    FutureProvider.family<bool, GameMode>((ref, mode) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.i('Updating game mode: ${mode.id}');
    final success = await service.updateGameMode(mode);
    if (success) {
      _logger.i('Game mode updated successfully: ${mode.id}');
      // Invalidate the list to refresh
      ref.invalidate(allGameModesProvider);
      ref.invalidate(activeGameModesProvider);
    }
    return success;
  } catch (e) {
    _logger.e('Error updating game mode: $e');
    rethrow;
  }
});

/// Delete a game mode (admin only)
final deleteGameModeProvider =
    FutureProvider.family<bool, String>((ref, modeId) async {
  try {
    final service = ref.watch(gameModeServiceProvider);
    _logger.i('Deleting game mode: $modeId');
    final success = await service.deleteGameMode(modeId);
    if (success) {
      _logger.i('Game mode deleted successfully: $modeId');
      // Invalidate the list to refresh
      ref.invalidate(allGameModesProvider);
      ref.invalidate(activeGameModesProvider);
    }
    return success;
  } catch (e) {
    _logger.e('Error deleting game mode: $e');
    rethrow;
  }
});

// ================== UI STATE PROVIDERS ==================

/// Game mode selection UI state
class GameModeUIState {
  final bool isLoading;
  final String? error;
  final GameMode? selectedMode;

  GameModeUIState({
    this.isLoading = false,
    this.error,
    this.selectedMode,
  });

  GameModeUIState copyWith({
    bool? isLoading,
    String? error,
    GameMode? selectedMode,
  }) {
    return GameModeUIState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedMode: selectedMode ?? this.selectedMode,
    );
  }
}

/// Notifier for game mode UI state
class GameModeUINotifier extends StateNotifier<GameModeUIState> {
  GameModeUINotifier() : super(GameModeUIState());

  void setLoading(bool loading) {
    // copyWith uses `?? this.field`, which can't distinguish "explicitly
    // null" from "not provided" - construct directly to actually clear it.
    state = GameModeUIState(
      isLoading: loading,
      error: null,
      selectedMode: state.selectedMode,
    );
  }

  void setError(String? error) {
    state = GameModeUIState(
      isLoading: false,
      error: error,
      selectedMode: state.selectedMode,
    );
  }

  void selectMode(GameMode mode) {
    state = GameModeUIState(
      isLoading: state.isLoading,
      error: null,
      selectedMode: mode,
    );
  }

  void clearSelection() {
    state = GameModeUIState(
      isLoading: state.isLoading,
      error: null,
      selectedMode: null,
    );
  }
}

/// Game mode UI state provider
final gameModeUIProvider =
    StateNotifierProvider<GameModeUINotifier, GameModeUIState>(
  (ref) => GameModeUINotifier(),
);

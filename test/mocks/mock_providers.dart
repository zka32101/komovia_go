import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

/// Mock providers for testing - override real providers with test data
class MockProviders {
  /// Mock current user
  static final currentUserProvider = StateProvider<User?>((ref) {
    return User(
      uid: 'test-user-123',
      email: 'test@example.com',
      displayName: 'Test Player',
      subscriptionActive: false,
      subscriptionStartDate: DateTime.now(),
      tutorialCompleted: true,
      gamesPlayedCount: 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  /// Mock subscription status
  static final isSubscriptionActiveProvider = StateProvider<bool>((ref) {
    return false;
  });

  /// Mock board state
  static final gameBoardStateProvider = StateProvider<BoardState>((ref) {
    return BoardState(
      boardSize: 9,
      stones: List.generate(
        9,
        (row) => List.generate(9, (col) => 0), // Empty board
      ),
      capturedBlack: 0,
      capturedWhite: 0,
      isBlackTurn: true,
    );
  });

  /// Mock game active state
  static final isGameActiveProvider = StateProvider<bool>((ref) {
    return true;
  });

  /// Mock AI level
  static final aiLevelProvider = StateProvider<int>((ref) {
    return 5;
  });

  /// Mock moves count
  static final movesCountProvider = StateProvider<int>((ref) {
    return 0;
  });

  /// Mock today's puzzle
  static final todaysTsumeProblemProvider =
      FutureProvider<TsumeGoProblem?>((ref) async {
    return TsumeGoProblem(
      id: 'tsume-001',
      difficulty: 2,
      sgfData: '(;GM[1]FF[4]CA[UTF-8]AP[Sabaki:0.52.3]KM[6.5]SZ[9];B[ee];W[de])',
      solutionSgf: '(;GM[1]FF[4];B[ee];W[de];B[df])',
      explanation: 'This is a test puzzle. Capture the white stone at D5.',
      source: 'Test Database',
      version: 1,
      createdAt: DateTime.now(),
    );
  });

  /// Mock puzzle solved state
  static final isPuzzleSolvedProvider = StateProvider<bool>((ref) {
    return false;
  });

  /// Mock puzzle attempt count
  static final puzzleAttemptCountProvider = StateProvider<int>((ref) {
    return 0;
  });

  /// Mock difficulty levels
  static final difficultyLevelsProvider = StateProvider<Map<int, String>>((ref) {
    return {
      1: 'Beginner',
      2: 'Easy',
      3: 'Medium',
      4: 'Hard',
      5: 'Expert',
    };
  });

  /// Mock selected difficulty
  static final selectedDifficultyProvider = StateProvider<int>((ref) {
    return 3;
  });

  /// Mock kifu library
  static final kifuLibraryProvider =
      FutureProvider<List<KifuLibrary>>((ref) async {
    return [
      KifuLibrary(
        id: 'kifu-001',
        title: 'Honinbo Shusaku vs Inoue Inseki',
        blackPlayer: 'Honinbo Shusaku',
        whitePlayer: 'Inoue Inseki',
        sgfData: '(;GM[1]FF[4]CA[UTF-8]AP[Sabaki:0.52.3]KM[0.5]SZ[19])',
        aiCommentaryData: null,
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'Go Archives',
        createdAt: DateTime.now(),
      ),
      KifuLibrary(
        id: 'kifu-002',
        title: 'AlphaGo vs Lee Sedol Game 1',
        blackPlayer: 'AlphaGo',
        whitePlayer: 'Lee Sedol',
        sgfData: '(;GM[1]FF[4]CA[UTF-8]AP[Sabaki:0.52.3]KM[7.5]SZ[19])',
        aiCommentaryData: null,
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'DeepMind',
        createdAt: DateTime.now(),
      ),
    ];
  });

  /// Mock game records
  static final userGameRecordsProvider =
      FutureProvider<List<GameRecord>>((ref) async {
    return [
      GameRecord(
        id: 'game-001',
        uid: 'test-user-123',
        boardSize: 9,
        sgfData: '(;GM[1]FF[4]CA[UTF-8])',
        result: GameResult.playerWin,
        blackScore: 45.5,
        whiteScore: 38.0,
        aiLevel: 3,
        playedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      GameRecord(
        id: 'game-002',
        uid: 'test-user-123',
        boardSize: 9,
        sgfData: '(;GM[1]FF[4]CA[UTF-8])',
        result: GameResult.aiWin,
        blackScore: 35.0,
        whiteScore: 42.5,
        aiLevel: 5,
        playedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  });

  /// Mock analytics provider for event logging
  static final analyticsProvider = StateProvider<MockAnalytics>((ref) {
    return MockAnalytics();
  });
}

/// Mock Analytics for testing
class MockAnalytics {
  final List<Map<String, dynamic>> events = [];

  void logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) {
    events.add({
      'name': name,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now(),
    });
  }

  void clearEvents() => events.clear();

  bool hasEvent(String name) => events.any((e) => e['name'] == name);

  int eventCount(String name) =>
      events.where((e) => e['name'] == name).length;
}

/// Extension to override providers in tests
extension ProviderContainerX on ProviderContainer {
  void setupMockProviders() {
    // Override with mock implementations
    // This will be used in individual test files
  }
}

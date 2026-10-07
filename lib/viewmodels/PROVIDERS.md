# Riverpod Providers - Phase 3 Documentation

This directory contains all Riverpod state management providers bridging the Services Layer (Phase 2) to the UI Views (Phase 4).

## Architecture Overview

```
Services Layer (Phase 2)          Viewmodels Layer (Phase 3)      Views Layer (Phase 4)
┌─────────────────────┐          ┌──────────────────────┐         ┌──────────────────┐
│ AuthService         │──────→   │ authProvider         │    ──→  │ AuthScreen       │
│ GoEngineService     │──────→   │ gameProvider         │    ──→  │ AIGameScreen     │
│ FirestoreService    │──────→   │ tsumeGoProvider      │    ──→  │ TsumeGoScreen    │
│ AIExplanationService│──────→   │ analyticsProvider    │    ──→  │ All Screens      │
└─────────────────────┘          └──────────────────────┘         └──────────────────┘
```

## Provider Categories

### 1. Authentication (auth_provider.dart)

#### State Providers
- `authStateProvider` - Stream of User? for reactive auth state
- `currentUserProvider` - Synchronous current user getter
- `isUserLoggedInProvider` - Boolean flag for routing logic
- `isSubscriptionActiveProvider` - Boolean flag for paywall logic

#### Action Providers
- `signUpProvider` - Sign up with email/password
- `signInProvider` - Sign in with email/password
- `signInAnonymouslyProvider` - Guest sign-in (unique feature)
- `linkAnonymousProvider` - Upgrade guest to persistent
- `signOutProvider` - Sign out current user
- `sendPasswordResetProvider` - Send password reset email
- `updateDisplayNameProvider` - Update user profile
- `deleteAccountProvider` - Delete user account (irreversible)
- `getIdTokenProvider` - Get Firebase ID token (debugging)

#### Usage Example

```dart
// In a Widget with ConsumerWidget:

class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current auth state
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // User is logged in
          return HomeScreen();
        } else {
          // Show login UI
          return LoginForm();
        }
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error: error),
    );
  }
}

// Trigger sign-in action
Future<void> handleSignIn(WidgetRef ref, String email, String password) async {
  final result = await ref.read(
    signInProvider(email: email, password: password).future
  );
  // Handle result...
}
```

### 2. Game State (game_provider.dart)

#### Board State Providers
- `gameBoardStateProvider` - Current board state (mutable)
- `aiLevelProvider` - AI difficulty 1-10 (mutable)
- `movesCountProvider` - Number of moves played (mutable)
- `lastPlayerPassedProvider` - Did last player pass? (mutable)
- `isGameActiveProvider` - Is game currently running? (mutable)
- `gameResultProvider` - Game end result (mutable)

#### Game Logic Providers
- `aiMoveProvider` - Request AI move; returns null until it's actually the AI's turn (auto-disposes)
- `validateMoveProvider` - Non-mutating legality check: occupancy, suicide, simple ko
- `applyMoveProvider` - `bool Function(row, col)`; applies a move (captures, turn, ko) for whichever side's turn it is
- `judgeGameEndProvider` - Judge game end & score (auto-disposes)

#### Move History
- `moveHistoryProvider` - List of moves played (mutable)
- `addMoveProvider` - Add move to history and update board

#### Game Records
- `saveGameRecordProvider` - Save completed game to Firestore
- `userGameRecordsProvider` - Fetch user's game history (paginated)
- `gameRecordProvider` - Fetch specific game record by ID

#### AI Configuration
- `selectedAiConfigProvider` - Current AI difficulty preset (mutable)
- `setAiConfigProvider` - Switch AI difficulty preset

#### Usage Example

```dart
// In a ConsumerWidget during active gameplay:

class AIGameScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch board state
    final boardState = ref.watch(gameBoardStateProvider);
    final aiLevel = ref.watch(aiLevelProvider);

    return Column(
      children: [
        // Display board...
        GoBoard(stones: boardState.stones),
        
        // Watch for AI move (null until it's actually the AI's turn)
        ref.watch(aiMoveProvider).whenData((aiMove) {
          if (aiMove != null) {
            ref.read(applyMoveProvider)(aiMove.row, aiMove.col);
          }
        }),
      ],
    );
  }
}

// Trigger AI move request after a legal player move
void requestAiMove(WidgetRef ref) {
  ref.invalidate(aiMoveProvider); // Requests new AI move
}

// Save game when finished (plain action provider, not a family — see
// its doc comment for why a FutureProvider.family would collide here)
void completeGame(WidgetRef ref, String uid) async {
  final gameId = await ref.read(saveGameRecordProvider)(
    uid: uid,
    boardSize: 9,
    result: 'win',
  );
}
```

### 3. Tsume-Go (Puzzle) State (tsume_go_provider.dart)

#### Puzzle State Providers
- `todaysTsumeProblemProvider` - Today's daily puzzle (deterministic)
- `currentTsumeProblemProvider` - Currently solving puzzle (mutable)
- `currentPuzzleBoardProvider` - Puzzle board state (mutable)
- `isPuzzleSolvedProvider` - Is current puzzle solved? (mutable)
- `puzzleAttemptCountProvider` - Number of attempts (mutable)
- `puzzleSolvingTimeProvider` - Time spent in seconds (mutable)

#### Puzzle Actions
- `loadPuzzleProvider` - Load specific puzzle by ID
- `tsumeProblemesByDifficultyProvider` - Get puzzles by difficulty
- `checkPuzzleSolutionProvider` - Check if solution is correct
- `recordPuzzleAttemptProvider` - Record attempt in Firestore

#### Streak Tracking
- `tsumeGoStreakProvider` - Get user's solving streak (in days)

#### Difficulty Selection
- `selectedDifficultyProvider` - Selected difficulty 1-5 (mutable)
- `difficultyLevelsProvider` - Map of difficulty→label
- `setDifficultyProvider` - Switch difficulty level

#### Puzzle History
- `userTsumeGoLogsProvider` - Fetch user's solving history

#### Usage Example

```dart
// In a ConsumerWidget during puzzle solving:

class TsumeGoScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch today's puzzle
    final todaysPuzzle = ref.watch(todaysTsumeProblemProvider);
    final isSolved = ref.watch(isPuzzleSolvedProvider);
    final attemptCount = ref.watch(puzzleAttemptCountProvider);

    return todaysPuzzle.when(
      data: (problem) {
        if (problem == null) {
          return Text('No puzzle available today');
        }
        
        return Column(
          children: [
            Text('Difficulty: ${problem.difficulty}'),
            Text('Attempts: $attemptCount'),
            if (isSolved)
              Text('✅ Puzzle solved!')
            else
              PuzzleBoard(sgfData: problem.sgfData),
          ],
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error: error),
    );
  }
}

// Submit solution
void submitPuzzleSolution(WidgetRef ref, String uid, String userSolutionSgf) async {
  final logId = await ref.read(
    recordPuzzleAttemptProvider(
      uid: uid,
      isCorrect: true,
      userSolutionSgf: userSolutionSgf,
    ).future
  );
}

// Get streak
void checkStreak(WidgetRef ref, String uid) {
  final streak = ref.watch(tsumeGoStreakProvider(uid));
  streak.whenData((days) => print('Streak: $days days'));
}
```

### 4. Analytics (analytics_provider.dart)

#### Core Events
- `logAhaMomentProvider` - Log when user reaches "aha moment"
- `logGameCompletedProvider` - Log game completion with result
- `logGameResignationProvider` - Log game resignation
- `logTsumeGoSolvedProvider` - Log puzzle solved
- `logTsumeGoAttemptedProvider` - Log puzzle attempt
- `logKifuObservationStartedProvider` - Log kifu watch start
- `logKifuObservationCompletedProvider` - Log kifu watch completion
- `logPaywallTriggeredProvider` - Log paywall shown (3rd game)
- `logPaywallDismissedProvider` - Log paywall dismissed
- `logPaywallConvertedProvider` - Log subscription purchased
- `logTutorialCompletedProvider` - Log tutorial completion
- `logTutorialSkippedProvider` - Log tutorial skip
- `logSignUpProvider` - Log user sign-up
- `logLogInProvider` - Log user login
- `logCustomEventProvider` - Log custom event

#### Usage Example

```dart
// In a ConsumerWidget:

class AIGameScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... game logic ...

    void endGame(String result) {
      // Log game completion
      ref.read(logGameCompletedProvider)(
        result: result,
        aiLevel: 5,
        boardSize: 9,
        movesCount: 47,
      );

      // Show results screen...
    }

    return GameBoard(...);
  }
}

// Log aha moment
void onAhaMoment(WidgetRef ref) {
  ref.read(logAhaMomentProvider)();
}
```

## Common Patterns

### Pattern 1: Watch + Update State

```dart
// Watch current board state
final boardState = ref.watch(gameBoardStateProvider);

// Update board state when move is made
ref.read(gameBoardStateProvider.notifier).state = newBoardState;
```

### Pattern 2: Future Provider with Auto-Dispose

```dart
// Watch AI move - auto-disposes when no longer watched
final aiMove = ref.watch(aiMoveProvider);

// Refresh to request new move
ref.refresh(aiMoveProvider);

// Read once (no watching)
final moveResult = await ref.read(aiMoveProvider.future);
```

### Pattern 3: Triggered Actions

```dart
// Read action provider and call it
await ref.read(signUpProvider(...).future);

// Or with completion handling
ref.listen(signUpProvider(...), (previous, next) {
  next.whenData((user) {
    // Handle successful signup
  });
});
```

### Pattern 4: Combining Providers

```dart
// Get user's game records when user ID changes
final userGames = ref.watch(
  userGameRecordsProvider(currentUserId)
);

// Combine multiple state values
final gameState = ref.watch(
  Riverpod.combine([
    gameBoardStateProvider,
    aiLevelProvider,
    movesCountProvider,
  ], (board, level, moves) => (...)),
);
```

## Testing Providers

```dart
// Mock service for testing
final mockFirestoreServiceProvider = Provider<FirestoreService>((ref) {
  return MockFirestoreService(); // Your mock implementation
});

// Override in tests
testWidgets('Game completion', (tester) async {
  await tester.pumpWidget(
    ProviderContainer(
      overrides: [
        firestoreServiceProvider.overrideWithValue(mockService),
      ],
      child: MyApp(),
    ),
  );
});
```

## Next Steps (Phase 4)

The providers in this layer are designed to be consumed by:

1. **SplashScreen** - Uses `authStateProvider` for route logic
2. **OnboardingScreen** - Uses `logTutorialCompletedProvider`
3. **HomeScreen** - Uses `isSubscriptionActiveProvider`, game/puzzle counts
4. **AIGameScreen** - Uses `aiMoveProvider`, `gameResultProvider`, `saveGameRecordProvider`
5. **TsumeGoScreen** - Uses `todaysTsumeProblemProvider`, `recordPuzzleAttemptProvider`
6. **KifuObservationScreen** - Uses `logKifuObservationCompletedProvider`
7. **GameHistoryScreen** - Uses `userGameRecordsProvider`
8. **PaywallScreen** - Uses `logPaywallTriggeredProvider`, `logPaywallConvertedProvider`
9. **SettingsScreen** - Uses auth/profile update providers

## Key Principles

1. **Single Responsibility** - Each provider manages one piece of state or one action
2. **Immutability** - State updates create new objects, don't mutate existing ones
3. **Error Handling** - All async providers handle errors; UI catches exceptions
4. **Logging** - All providers use Logger for production debugging
5. **Auto-Dispose** - Expensive providers use `.autoDispose` to free resources
6. **Caching** - Providers cache results; refresh() to invalidate cache
7. **Type Safety** - Strong typing throughout; no dynamic types

## References

- Riverpod docs: https://riverpod.dev
- Flutter state management: https://flutter.dev/docs/development/data-and-backend/state-mgmt
- CLAUDE.md for architecture overview
- Services (Phase 2) for underlying logic

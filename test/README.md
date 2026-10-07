# GoEn Test Suite

Comprehensive widget, unit, and integration tests for the GoEn Flutter application.

## Directory Structure

```
test/
├── screens/              # Widget tests for UI screens
├── mocks/               # Mock providers and test doubles
├── fixtures/            # Test data and fixtures
├── test_utils.dart      # Common test utilities
└── README.md           # This file
```

## Test Files

### Widget Tests (test/screens/)

- **splash_screen_test.dart** - SplashScreen initialization and routing
- **onboarding_screen_test.dart** - 3-card tutorial flow and navigation
- **home_screen_test.dart** - Main hub, action cards, user section
- **ai_game_screen_test.dart** - Interactive board, stone placement, AI integration
- **game_result_screen_test.dart** - Score display, statistics, post-game actions
- **tsume_go_screen_test.dart** - Daily puzzle, difficulty selection, solution checking
- **kifu_observation_screen_test.dart** - Historical game library, move replay
- **game_history_screen_test.dart** - Past games browsing, filtering, sorting
- **settings_screen_test.dart** - User preferences, account management
- **paywall_screen_test.dart** - Subscription pricing, purchase flow

### Mock Providers (test/mocks/)

**mock_providers.dart** - StateProvider overrides for testing:
- `authStateProvider` - Mock authentication state
- `currentUserProvider` - Mock user data
- `gameBoardStateProvider` - Mock board state
- `todaysTsumeProblemProvider` - Mock daily puzzle
- `kifuLibraryProvider` - Mock historical games
- `analyticsProvider` - Mock event logging

### Test Fixtures (test/fixtures/)

**test_data.dart** - Reusable test data:
- `testUser` - Regular user fixture
- `premiumUser` - Premium user fixture
- `tsumeGoProblem` - Sample puzzle
- `gameRecordWin` / `gameRecordLoss` - Game fixtures
- `honinboGame` - Historical game
- `alphagonGame` - Modern AI game

### Test Utilities (test/test_utils.dart)

**TestUtils class** - Common testing helpers:
- `createTestContainer()` - ProviderContainer with mocks
- `buildTestableWidget()` - Widget wrapping with providers
- `pumpAndSettle()` - Standard settling
- `tap()`, `enterText()`, `scrollToWidget()` - User interactions
- `expectText()`, `expectExists()` - Assertions

**WidgetTesterX extension** - Convenience methods for WidgetTester

## Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/screens/splash_screen_test.dart

# Run tests matching pattern
flutter test --name "HomeScreen"

# Run with coverage
flutter test --coverage

# Run tests in verbose mode
flutter test -v
```

## Test Coverage Goals

| Component | Target Coverage | Status |
|-----------|-----------------|--------|
| Screens | 80%+ | 🔄 In Progress |
| ViewModels | 85%+ | ✅ Complete (Phase 3) |
| Models | 90%+ | ✅ Complete (Phase 1) |
| Services | 85%+ | ✅ Complete (Phase 2) |

## Writing New Tests

### Basic Widget Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import '../test_utils.dart';
import '../fixtures/test_data.dart';

void main() {
  group('MyScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
      );
    });

    testWidgets('renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const MyScreen(),
          container: container,
        ),
      );

      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
```

### Using Mock Providers

```dart
// Override specific provider
final customContainer = ProviderContainer(
  overrides: [
    currentUserProvider.overrideWithValue(TestData.premiumUser),
    isSubscriptionActiveProvider.overrideWithValue(true),
  ],
);
```

### Testing User Interactions

```dart
// Tap a button
await TestUtils.tap(tester, find.text('Submit'));

// Enter text
await TestUtils.enterText(tester, find.byType(TextField), 'Hello');

// Scroll to widget
await TestUtils.scrollToWidget(tester, find.text('Hidden Text'));
```

## Testing Best Practices

1. **Isolate units** - Mock external dependencies
2. **Use fixtures** - Reusable test data reduces duplication
3. **Test behavior** - Focus on user actions, not implementation
4. **Clear assertions** - Use descriptive expect() messages
5. **Setup/teardown** - Proper test isolation with setUp/tearDown
6. **Fast execution** - Keep tests snappy (< 1s per test)
7. **Meaningful names** - Test names should explain what's being tested

## Common Testing Patterns

### Testing Navigation

```dart
testWidgets('navigates to detail screen', (tester) async {
  // Build widget with MaterialApp for navigation
  await tester.pumpWidget(
    TestUtils.buildTestableWidget(
      child: MaterialApp(
        home: const MyScreen(),
        routes: {'/detail': (_) => const DetailScreen()},
      ),
      container: container,
    ),
  );

  // Tap to navigate
  await TestUtils.tap(tester, find.text('Go to Detail'));
  
  // Verify new route
  expect(find.byType(DetailScreen), findsWidgets);
});
```

### Testing Async Operations

```dart
testWidgets('loads data', (tester) async {
  // During initial load
  expect(find.byType(CircularProgressIndicator), findsWidgets);

  // After settling
  await tester.pumpAndSettle();
  
  // Verify loaded data
  expect(find.text('Loaded Data'), findsWidgets);
});
```

### Testing User Input Validation

```dart
testWidgets('validates email', (tester) async {
  await tester.pumpWidget(buildTestWidget());

  // Enter invalid email
  await TestUtils.enterText(tester, find.byType(TextField), 'invalid');
  
  // Tap submit
  await TestUtils.tap(tester, find.text('Submit'));

  // Verify error message
  expect(find.text('Invalid email'), findsWidgets);
});
```

## Debugging Tests

### Enable logging
```bash
flutter test -v
```

### Pause test execution
```dart
// Add to test
await tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
// Test will pause here in IDE
```

### Take screenshots (golden tests)
```dart
expect(find.byType(MyScreen), matchesGoldenFile('my_screen.png'));
```

### Print widget tree
```dart
printToConsole(tester.binding.debugPrintBeginFrame);
```

## CI/CD Integration

Tests run automatically on:
- Every push to development branch
- Pull request before merge
- Pre-merge checks on main branch

See `.github/workflows/test.yml` for CI configuration.

## Known Limitations & TODOs

- [ ] Integration tests with real Firebase (Phase 6.2)
- [ ] Golden image tests for board rendering (Phase 6.3)
- [ ] Performance tests for AI move calculation (Phase 6.4)
- [ ] Accessibility tests for color contrast (Phase 6.5)
- [ ] E2E tests for critical user flows (Phase 6.6)

## References

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Riverpod Testing Guide](https://riverpod.dev/docs/guides/testing)
- [Widget Testing Best Practices](https://flutter.dev/docs/testing/best-practices)

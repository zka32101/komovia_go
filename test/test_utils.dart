import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';

/// Utility class for common test setup operations
class TestUtils {
  /// Creates a ProviderContainer with default mock overrides
  static ProviderContainer createTestContainer({
    User? currentUser,
    bool isSubscriptionActive = false,
    int aiLevel = 5,
    bool isGameActive = true,
    int movesCount = 0,
    BoardState? boardState,
    List<Override> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        // Override auth providers
        currentUserProvider.overrideWithValue(currentUser),
        isSubscriptionActiveProvider.overrideWithValue(isSubscriptionActive),

        // Override game providers
        aiLevelProvider.overrideWith((ref) => aiLevel),
        isGameActiveProvider.overrideWith((ref) => isGameActive),
        movesCountProvider.overrideWith((ref) => movesCount),
        gameBoardStateProvider.overrideWith(
          (ref) =>
              boardState ??
              BoardState(
                boardSize: 9,
                stones: List.generate(
                  9,
                  (row) => List.generate(9, (col) => 0),
                ),
                capturedBlack: 0,
                capturedWhite: 0,
                isBlackTurn: true,
              ),
        ),
        ...extraOverrides,
      ],
    );

    return container;
  }

  /// Wraps a widget with necessary providers and Material app
  static Widget buildTestableWidget({
    required Widget child,
    ProviderContainer? container,
  }) {
    final testContainer = container ?? createTestContainer();

    return UncontrolledProviderScope(
      container: testContainer,
      child: MaterialApp(
        home: child,
        theme: ThemeData.dark(),
        navigatorObservers: [],
        // Matches GoEnApp's actual default (localeProvider starts at 'ja')
        // so widget tests see the same strings production users do by
        // default, instead of falling back to the test harness's 'en'.
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  /// Helper to pump and settle
  static Future<void> pumpAndSettle(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  /// Find widget by text
  static Finder findByText(String text) {
    return find.text(text);
  }

  /// Find widget by type
  static Finder findByType<T extends Widget>() {
    return find.byType(T);
  }

  /// Verify widget exists
  static void expectExists(Finder finder) {
    expect(finder, findsWidgets);
  }

  /// Verify widget doesn't exist
  static void expectNotExists(Finder finder) {
    expect(finder, findsNothing);
  }

  /// Tap a widget
  static Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
  }

  /// Enter text into a field
  static Future<void> enterText(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, text);
    await tester.pump();
  }

  /// Verify text exists
  static void expectText(String text) {
    expect(find.text(text), findsWidgets);
  }

  /// Verify text doesn't exist
  static void expectNoText(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Scroll to widget
  static Future<void> scrollToWidget(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.scrollUntilVisible(
      finder,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Get binding for testing
  static WidgetsBinding getBinding() => WidgetsBinding.instance;
}

/// Extension on WidgetTester for convenience methods
extension WidgetTesterX on WidgetTester {
  /// Pump app with default delay
  Future<void> pumpApp({Duration delay = const Duration(milliseconds: 100)}) =>
      pumpAndSettle(delay);

  /// Verify scaffold exists
  Finder findScaffold() => find.byType(Scaffold);

  /// Verify app bar exists
  Finder findAppBar() => find.byType(AppBar);

  /// Get rendered text widget
  Text getTextWidget(Finder finder) => firstWidget(finder);
}

/// Mock implementation of analytics provider for testing
class MockAnalyticsProvider {
  final List<Map<String, dynamic>> loggedEvents = [];

  void logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) {
    loggedEvents.add({
      'name': name,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now(),
    });
  }

  void clearEvents() => loggedEvents.clear();

  bool hasEvent(String name) => loggedEvents.any((e) => e['name'] == name);

  int eventCount(String name) =>
      loggedEvents.where((e) => e['name'] == name).length;

  void verifyEventLogged(String eventName) {
    expect(hasEvent(eventName), true,
        reason: 'Event "$eventName" was not logged');
  }

  void verifyEventNotLogged(String eventName) {
    expect(hasEvent(eventName), false,
        reason: 'Event "$eventName" was logged but should not be');
  }
}

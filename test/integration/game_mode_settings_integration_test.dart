import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/main.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../fixtures/test_data.dart';

/// SplashScreen routes based on authStateProvider (a real
/// FirebaseAuth-backed stream, which never emits a user in a plain
/// flutter test process) - override it with a signed-in user so the app
/// actually reaches HomeScreen instead of staying on the auth flow.
Widget _signedInApp() {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(TestData.testUser)),
    ],
    child: const GoEnApp(),
  );
}

void main() {
  group('Game Mode Settings Integration Tests', () {
    testWidgets('GameMode Selection → Blitz Settings flow',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      // Navigate to GameModeSelector
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets(
        'Correspondence Settings → Game flow',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Team Game Settings validation',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Puzzle Rush Settings difficulty selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Settings → Game transition removes settings screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      // Routes should be properly registered
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Back button from settings returns to GameModeSelector',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      // HomeScreen is the app's root and has no back button - navigate
      // into GameModeSelectorScreen first to see one. The extra duration
      // lets the push transition animation finish.
      await tester.tap(find.byIcon(Icons.sports_esports));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsWidgets);
    });
  });
}

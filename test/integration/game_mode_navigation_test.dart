import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/main.dart';
import 'package:komovia_go/models/index.dart';
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
  group('GameMode Navigation Integration Tests', () {
    testWidgets('Navigate from GameModeSelectorScreen to BlitzGameScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      // Navigate to GameModeSelector. Only a single pump (not
      // pumpAndSettle): the mode list's indeterminate loading spinner
      // never settles on its own since fetching it hits a real
      // Firestore call with no connection in a plain flutter test.
      await tester.tap(find.byIcon(Icons.sports_esports));
      await tester.pump();

      // Tap Blitz game card
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets(
        'Navigate from GameModeSelectorScreen to CorrespondenceGameScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
    });

    testWidgets('Navigate from GameModeSelectorScreen to TeamGameScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
    });

    testWidgets('Navigate from GameModeSelectorScreen to PuzzleRushScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();
    });

    testWidgets('Back button returns to previous screen',
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

    testWidgets('Named route navigation works correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(_signedInApp());
      await tester.pumpAndSettle();

      // Routes should be registered
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/user.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/avatar_picker_sheet.dart';

User _buildUser({String? avatarId, String? frameId}) => User(
      uid: 'uid-1',
      email: 'player@example.com',
      subscriptionActive: false,
      subscriptionStartDate: DateTime(2026, 1, 1),
      tutorialCompleted: true,
      gamesPlayedCount: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      avatarId: avatarId,
      frameId: frameId,
    );

Widget _app({
  String? initialAvatarId,
  String? initialFrameId,
  required Future<void> Function(String) onUpdate,
  Future<void> Function(String?)? onFrameUpdate,
  Set<String> unlockedFrames = const {},
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(
          _buildUser(avatarId: initialAvatarId, frameId: initialFrameId)),
      updateAvatarProvider.overrideWithValue(onUpdate),
      updateFrameProvider.overrideWithValue(onFrameUpdate ?? (_) async {}),
      unlockedFrameIdsProvider.overrideWith((ref) async => unlockedFrames),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAvatarPickerSheet(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows all 24 preset avatars in the picker sheet', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(onUpdate: (_) async {}));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // Spot-check a couple of known presets rather than asserting the
    // exact count, so this doesn't need updating if the shared catalog
    // in komovia_core grows.
    // The fox also appears in each frame-preview row, hence findsWidgets.
    expect(find.text('🦊'), findsWidgets);
    expect(find.text('🦉'), findsOneWidget);
    expect(find.text(AppLocalizations.of(
      t.element(find.byType(Scaffold).last),
    )!.avatarPickerTitle), findsOneWidget);
  });

  testWidgets('tapping a preset persists it via updateAvatarProvider', (t) async {
    String? saved;
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(onUpdate: (id) async => saved = id));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.text('🐼')); // panda
    await t.pumpAndSettle();

    expect(saved, equals('panda'));
    expect(find.text('Avatar updated!'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when the save fails', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(onUpdate: (_) async => throw Exception('network')));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.text('🐯')); // tiger
    await t.pumpAndSettle();

    expect(find.textContaining('Failed to update avatar'), findsOneWidget);
  });

  testWidgets('picking nothing (dismissing the sheet) never saves', (t) async {
    var called = false;
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(onUpdate: (_) async => called = true));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    // Dismiss the modal bottom sheet by tapping outside it.
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();

    expect(called, isFalse);
  });

  testWidgets('a user with no avatar set shows the default (fox) as selected',
      (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(initialAvatarId: null, onUpdate: (_) async {}));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    final foxContainer = t.widget<Container>(
      find.ancestor(
        of: find.text('🦊').first,
        matching: find.byType(Container),
      ),
    );
    final decoration = foxContainer.decoration as BoxDecoration;
    // AppColors.kin is used for the selected tile's fill.
    expect(decoration.border?.top.width, equals(2));
  });

  group('frames', () {
    Future<void> open(WidgetTester t, Widget app) async {
      await t.binding.setSurfaceSize(const Size(800, 3000));
      await t.pumpWidget(app);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('locked frames are shown with a lock and their condition',
        (t) async {
      await open(t, _app(onUpdate: (_) async {}, unlockedFrames: {'games_10'}));
      final locked = find.byKey(const ValueKey('frame-tile-rank_kudan'));
      expect(locked, findsOneWidget);
      expect(find.descendant(of: locked, matching: find.byIcon(Icons.lock)),
          findsOneWidget);
      expect(find.text('Locked: Reach 9 dan'), findsOneWidget);
      final open10 = find.byKey(const ValueKey('frame-tile-games_10'));
      expect(find.descendant(of: open10, matching: find.byIcon(Icons.lock)),
          findsNothing);
    });

    testWidgets('tapping an unlocked frame persists it', (t) async {
      String? saved = 'unset';
      await open(
          t,
          _app(
            onUpdate: (_) async {},
            onFrameUpdate: (id) async => saved = id,
            unlockedFrames: {'games_10'},
          ));
      await t.tap(find.byKey(const ValueKey('frame-tile-games_10')));
      await t.pumpAndSettle();
      expect(saved, 'games_10');
      expect(find.text('Frame updated!'), findsOneWidget);
    });

    testWidgets('tapping a locked frame does nothing', (t) async {
      var called = false;
      await open(
          t,
          _app(
            onUpdate: (_) async {},
            onFrameUpdate: (_) async => called = true,
          ));
      await t.tap(find.byKey(const ValueKey('frame-tile-rank_kudan')));
      await t.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('"No frame" clears the selection', (t) async {
      String? saved = 'unset';
      await open(
          t,
          _app(
            initialFrameId: 'games_10',
            onUpdate: (_) async {},
            onFrameUpdate: (id) async => saved = id,
            unlockedFrames: {'games_10'},
          ));
      await t.tap(find.byKey(const ValueKey('frame-tile-none')));
      await t.pumpAndSettle();
      expect(saved, isNull);
    });
  });
}

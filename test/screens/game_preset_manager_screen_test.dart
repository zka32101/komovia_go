import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/services/game_preset_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/game_preset_manager_screen.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: const GamePresetManagerScreen(),
      theme: ThemeData.dark(),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/blitz-game': (_) => const Scaffold(body: Text('BLITZ_GAME_SCREEN')),
      },
    ),
  );
}

void main() {
  group('GamePresetManagerScreen', () {
    late FakeFirebaseFirestore firestore;
    late GamePresetService service;
    final uid = TestData.testUser.uid;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = GamePresetService(firestore: firestore);
    });

    ProviderContainer buildContainer() {
      return TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        extraOverrides: [
          gamePresetServiceProvider.overrideWithValue(service),
        ],
      );
    }

    testWidgets('edits an existing preset', (tester) async {
      await service.createPreset(
        userId: uid,
        name: 'My Blitz Setup',
        gameMode: 'blitz',
        boardSize: 13,
        aiLevel: 4,
        playerColor: 'black',
      );

      await tester.pumpWidget(_buildApp(buildContainer()));
      await tester.pump();
      await tester.pump();

      expect(find.text('My Blitz Setup'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();

      expect(find.text('プリセットを編集'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Renamed Setup');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('Renamed Setup'), findsOneWidget);
      expect(find.text('My Blitz Setup'), findsNothing);

      final presets = await service.getUserPresets(userId: uid);
      expect(presets.single.name, 'Renamed Setup');
    });

    testWidgets('duplicates a preset', (tester) async {
      await service.createPreset(
        userId: uid,
        name: 'My Blitz Setup',
        gameMode: 'blitz',
        boardSize: 13,
        aiLevel: 4,
        playerColor: 'black',
      );

      await tester.pumpWidget(_buildApp(buildContainer()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('複製'));
      await tester.pumpAndSettle();

      final presets = await service.getUserPresets(userId: uid);
      expect(presets.length, 2);
      expect(presets.any((p) => p.name == 'My Blitz Setupのコピー'), true);

      expect(find.text('My Blitz Setupのコピー'), findsOneWidget);
    });

    testWidgets('plays a blitz preset by navigating to the blitz game', (tester) async {
      await service.createPreset(
        userId: uid,
        name: 'My Blitz Setup',
        gameMode: 'blitz',
        boardSize: 13,
        aiLevel: 4,
        playerColor: 'black',
      );

      await tester.pumpWidget(_buildApp(buildContainer()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('このプリセットでゲーム開始'));
      await tester.pumpAndSettle();

      expect(find.text('BLITZ_GAME_SCREEN'), findsOneWidget);

      final presets = await service.getUserPresets(userId: uid);
      expect(presets.single.usageCount, 1);
    });

    testWidgets('shows an honest message when playing a non-blitz preset', (tester) async {
      await service.createPreset(
        userId: uid,
        name: 'Training Setup',
        gameMode: 'correspondence',
        boardSize: 19,
        aiLevel: 3,
        playerColor: 'black',
      );

      final container = buildContainer();
      await tester.pumpWidget(_buildApp(container));
      // Switch the mode filter to correspondence to see the preset.
      await tester.tap(find.text('対局'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('このプリセットでゲーム開始'));
      await tester.pump();
      await tester.pump();

      expect(find.text('このモードのプリセットからの開始には対応していません'), findsOneWidget);
      expect(find.text('BLITZ_GAME_SCREEN'), findsNothing);
    });

    testWidgets('deletes a preset and refreshes the list', (tester) async {
      await service.createPreset(
        userId: uid,
        name: 'My Blitz Setup',
        gameMode: 'blitz',
        boardSize: 13,
        aiLevel: 4,
        playerColor: 'black',
      );

      await tester.pumpWidget(_buildApp(buildContainer()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除').last);
      await tester.pumpAndSettle();

      expect(find.text('My Blitz Setup'), findsNothing);
      final presets = await service.getUserPresets(userId: uid);
      expect(presets, isEmpty);
    });
  });
}

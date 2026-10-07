import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/ai_opponent_config.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/ai_level_sheet.dart';

Widget _app({required bool premium, required void Function(bool) onResult}) {
  return ProviderScope(
    overrides: [isSubscriptionActiveProvider.overrideWithValue(premium)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {'/paywall': (_) => const Scaffold(body: Text('PAYWALL'))},
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  onResult(await showAiLevelSheet(context, ref)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('free user: levels above the free cap show a lock', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    await t.pumpWidget(_app(premium: false, onResult: (_) {}));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    final locked = AIOpponentConfig.maxLevel - AIOpponentConfig.freeMaxLevel;
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(locked));
    expect(find.text('Level 5'), findsOneWidget);
    expect(find.text('Level 6'), findsOneWidget);
  });

  testWidgets('free user: tapping a locked level opens the paywall', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    var picked = true;
    await t.pumpWidget(_app(premium: false, onResult: (v) => picked = v));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.text('Level 8'));
    await t.pumpAndSettle();

    expect(find.text('PAYWALL'), findsOneWidget);
    expect(picked, isFalse);
  });

  testWidgets('premium user: no locks, can start at level 8', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    var picked = false;
    late WidgetRef capturedRef;
    await t.pumpWidget(
      ProviderScope(
        overrides: [isSubscriptionActiveProvider.overrideWithValue(true)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async =>
                      picked = await showAiLevelSheet(context, ref),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await t.tap(find.text('Level 8'));
    await t.pump();
    await t.tap(find.text('Play at this strength'));
    await t.pumpAndSettle();

    expect(picked, isTrue);
    expect(capturedRef.read(aiLevelProvider), 8);
  });

  testWidgets('free user: a stale high level is clamped to the free cap',
      (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1600));
    var picked = false;
    late WidgetRef capturedRef;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          isSubscriptionActiveProvider.overrideWithValue(false),
          aiLevelProvider.overrideWith((ref) => 9),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async =>
                      picked = await showAiLevelSheet(context, ref),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Play at this strength'));
    await t.pumpAndSettle();

    expect(picked, isTrue);
    expect(capturedRef.read(aiLevelProvider), AIOpponentConfig.freeMaxLevel);
  });
}

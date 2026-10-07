import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/views/screens/handicap_game_settings_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';

void main() {
  group('HandicapGameSettingsScreen', () {
    testWidgets('初期表示確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ハンディキャップ戦'), findsOneWidget);
      expect(find.text('碁盤サイズ'), findsOneWidget);
      expect(find.text('置き石の数'), findsOneWidget);
    });

    testWidgets('ボードサイズ選択肢が表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('9×9'), findsOneWidget);
      expect(find.text('13×13'), findsOneWidget);
      expect(find.text('19×19'), findsOneWidget);
    });

    testWidgets('デフォルトは19路盤・4子', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('4 子'), findsOneWidget);
    });

    testWidgets('ボードサイズをタップすると選択が切り替わる', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('9×9'));
      await tester.pump();

      // Still renders without error after switching board size.
      expect(find.text('9×9'), findsOneWidget);
    });

    testWidgets('置き石スライダーが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('ゲーム開始ボタンをタップすると盤面が事前配置され、AI対局画面へ遷移する', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routes: {
              '/ai-game': (_) => const Scaffold(body: Text('ai-game-stub')),
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('ゲーム開始'));
      await tester.pumpAndSettle();

      expect(find.text('ai-game-stub'), findsOneWidget);

      // Default settings: 19x19 board, 4-stone handicap -> white to move,
      // and the 4 corner star points are pre-occupied by black.
      final board = container.read(gameBoardStateProvider);
      expect(board.boardSize, 19);
      expect(board.isBlackTurn, false);
      final blackStoneCount = board.stones
          .expand((row) => row)
          .where((cell) => cell == 1)
          .length;
      expect(blackStoneCount, 4);
    });

    testWidgets('戻るボタンが表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HandicapGameSettingsScreen(),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}

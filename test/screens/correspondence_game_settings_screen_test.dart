import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/views/screens/correspondence_game_settings_screen.dart';

void main() {
  group('CorrespondenceGameSettingsScreen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('初期表示確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CorrespondenceGameSettingsScreen()),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('ターンベース対局設定'), findsOneWidget);
      expect(find.text('碁盤サイズ'), findsOneWidget);
      expect(find.text('手番'), findsOneWidget);
    });

    testWidgets('手番選択確認', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CorrespondenceGameSettingsScreen()),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('黒'), findsOneWidget);
      expect(find.text('白'), findsOneWidget);
      expect(find.text('ランダム'), findsOneWidget);
    });

    testWidgets('考慮時間情報表示', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CorrespondenceGameSettingsScreen()),
            theme: ThemeData.dark(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('考慮時間'), findsOneWidget);
      expect(find.text('1手につき24時間の考慮時間があります'), findsOneWidget);
    });
  });
}

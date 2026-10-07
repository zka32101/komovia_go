import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/screens/pvp_games_list_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';

import '../fixtures/test_data.dart';

PvpGame _buildGame({
  required String id,
  required bool isBlackTurn,
  int movesCount = 4,
  DateTime? updatedAt,
}) {
  return PvpGame(
    id: id,
    boardSize: 9,
    blackUid: TestData.testUser.uid,
    blackDisplayName: TestData.testUser.displayName!,
    whiteUid: 'opponent-uid',
    whiteDisplayName: 'Opponent Player',
    stones: List.generate(9, (_) => List.filled(9, 0)),
    isBlackTurn: isBlackTurn,
    capturedBlack: 0,
    capturedWhite: 0,
    movesCount: movesCount,
    consecutivePasses: 0,
    status: 'active',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt,
  );
}

void main() {
  group('PvpGamesListScreen', () {
    testWidgets('shows the empty state when there are no active games',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userActivePvpGamesProvider(TestData.testUser.uid)
              .overrideWith((ref) async => <PvpGame>[]),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const PvpGamesListScreen(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('進行中のPvP対局はありません'), findsOneWidget);
    });

    testWidgets('lists active games and shows whose turn it is',
        (WidgetTester tester) async {
      final games = [
        _buildGame(id: 'game-1', isBlackTurn: true),
        _buildGame(id: 'game-2', isBlackTurn: false),
      ];
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userActivePvpGamesProvider(TestData.testUser.uid)
              .overrideWith((ref) async => games),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const PvpGamesListScreen(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('vs Opponent Player'), findsNWidgets(2));
      expect(find.text('あなたの番'), findsOneWidget);
      expect(find.text('相手の番'), findsOneWidget);
    });

    testWidgets(
        'shows a forfeit-claim button when the opponent has gone stale and it is not my turn',
        (WidgetTester tester) async {
      final games = [
        // isBlackTurn: false → it's white's (the opponent's) turn, and the
        // game hasn't been touched in well over 48 hours.
        _buildGame(
          id: 'stale-game',
          isBlackTurn: false,
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userActivePvpGamesProvider(TestData.testUser.uid)
              .overrideWith((ref) async => games),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const PvpGamesListScreen(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('相手が長時間応答していません'), findsOneWidget);
      expect(find.text('放棄による勝利を申請する'), findsOneWidget);
    });

    testWidgets('does not show a forfeit-claim button for a recently active game',
        (WidgetTester tester) async {
      final games = [
        _buildGame(
          id: 'fresh-game',
          isBlackTurn: false,
          updatedAt: DateTime.now(),
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(TestData.testUser),
          userActivePvpGamesProvider(TestData.testUser.uid)
              .overrideWith((ref) async => games),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: const PvpGamesListScreen(),
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('相手が長時間応答していません'), findsNothing);
      expect(find.text('放棄による勝利を申請する'), findsNothing);
    });
  });
}

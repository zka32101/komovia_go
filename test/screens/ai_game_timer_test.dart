// 項目5: オプションのタイマーモード。碁縁の既定は「タイマーなし」の
// ままであること、選んだ場合は正しい側（人間=黒／AI=白）が時間切れで
// 負けになることを確認する。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/ai_game_screen.dart';
import 'package:komovia_go/views/widgets/go_chess_clock.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// 他の画面へ実際に遷移させずに検証するための最小限のテストApp。
Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData.dark(),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/ai-game',
      routes: {
        '/ai-game': (_) => const AIGameScreen(),
        '/game-result': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, Object?>;
          return Scaffold(body: Text('RESULT:${args['result']}'));
        },
      },
    ),
  );
}

void main() {
  group('AIGameScreen 項目5: タイマーモード', () {
    testWidgets('デフォルト（タイマーなし）では時計が表示されない',
        (WidgetTester tester) async {
      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        isGameActive: true,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();

      expect(find.byType(GoChessClock), findsNothing);
    });

    testWidgets('タイマーモードを選んだ場合、両者の時計が表示される',
        (WidgetTester tester) async {
      const timeControl = core.TimeControl(initial: Duration(minutes: 5));
      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState,
        isGameActive: true,
        extraOverrides: [
          activeTimeControlProvider.overrideWith((ref) => timeControl),
          blackTimeRemainingProvider.overrideWith(
            (ref) => const Duration(minutes: 5),
          ),
          whiteTimeRemainingProvider.overrideWith(
            (ref) => const Duration(minutes: 5),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();

      expect(find.byType(GoChessClock), findsOneWidget);
      expect(find.text('05:00'), findsWidgets);
    });

    testWidgets(
        '黒（人間）の時間切れは黒の負け（白の勝ち）として終局する - '
        '誤って逆の側が負けにならないことを確認する正当性のテスト',
        (WidgetTester tester) async {
      const timeControl = core.TimeControl(initial: Duration(seconds: 5));
      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState.copyWith(isBlackTurn: true),
        isGameActive: true,
        extraOverrides: [
          activeTimeControlProvider.overrideWith((ref) => timeControl),
          // 黒の残り時間をほぼ0にしておき、1 tick (200ms)で時間切れに
          // なるようにする。
          blackTimeRemainingProvider.overrideWith(
            (ref) => const Duration(milliseconds: 150),
          ),
          whiteTimeRemainingProvider.overrideWith(
            (ref) => const Duration(seconds: 5),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();
      expect(container.read(isGameActiveProvider), isTrue);

      // ティッカーの間隔(200ms)を1回分進める。
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // 黒（人間）が時間切れになったので、人間の負け = resultLabel 'lose'。
      expect(find.text('RESULT:lose'), findsOneWidget);
      expect(container.read(isGameActiveProvider), isFalse);
    });

    testWidgets(
        '白（AI）の時間切れは黒の勝ちとして終局する（手番が白のときのみ'
        '白の時計が進むことの確認）', (WidgetTester tester) async {
      const timeControl = core.TimeControl(initial: Duration(seconds: 5));
      final container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        boardState: TestData.emptyBoardState.copyWith(isBlackTurn: false),
        isGameActive: true,
        extraOverrides: [
          activeTimeControlProvider.overrideWith((ref) => timeControl),
          blackTimeRemainingProvider.overrideWith(
            (ref) => const Duration(seconds: 5),
          ),
          whiteTimeRemainingProvider.overrideWith(
            (ref) => const Duration(milliseconds: 150),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // 白（AI）が時間切れになったので、人間の勝ち = resultLabel 'win'。
      expect(find.text('RESULT:win'), findsOneWidget);
      expect(container.read(isGameActiveProvider), isFalse);
    });
  });
}

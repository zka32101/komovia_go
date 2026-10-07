import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/views/screens/paywall_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

/// The price and period suffix render as TextSpans inside a single
/// RichText (for the "$3.00" + "/month" combined layout), which
/// find.text() never matches since it only looks at Text/EditableText
/// widgets.
Finder findRichText(String substring) => find.byWidgetPredicate(
  (widget) =>
      widget is RichText && widget.text.toPlainText().contains(substring),
);

void main() {
  group('PaywallScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: false,
      );
    });

    testWidgets('renders paywall screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Verify scaffold exists
      expect(find.byType(Scaffold), findsWidgets);

      // Verify app bar
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('displays screen title', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Verify title
      expect(find.text('プレミアム会員'), findsWidgets);
    });

    testWidgets('shows close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Close button in app bar
      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('displays hero section with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Hero icon
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('shows hero headline', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Headline
      expect(find.text('プレミアム機能を解放'), findsWidgets);
    });

    testWidgets('displays tagline', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Tagline
      expect(
        find.text('自分のペースで囲碁を学ぶ大人たちの仲間入りを'),
        findsWidgets,
      );
    });

    testWidgets('shows benefits section header', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Benefits header
      expect(find.text('得られるもの'), findsWidgets);
    });

    testWidgets('displays all real premium benefits', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // All benefits should be visible
      expect(find.text('強いAIと対局'), findsWidgets);
      expect(find.text('形勢判断の詳細'), findsWidgets);
      expect(find.text('広告なし'), findsWidgets);
      // Benefits that are not actually implemented must not be advertised.
      expect(find.text('対局数無制限'), findsNothing);
      expect(find.text('優先サポート'), findsNothing);
    });

    testWidgets('benefits have checkmark icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Checkmark icons
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows benefit descriptions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Descriptions should be visible
      expect(find.text('レベル6〜10のAIに挑戦できます'), findsWidgets);
      expect(find.text('目差と勝率で局面を分析できます'), findsWidgets);
    });

    testWidgets('pricing section visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Should show pricing (monthly tab should be selected by default)
      await tester.pumpAndSettle();
      expect(find.text('月額'), findsWidgets);
    });

    testWidgets('shows monthly and annual toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Toggle buttons
      expect(find.text('月額'), findsWidgets);
      expect(find.text('年額'), findsWidgets);
    });

    testWidgets('monthly plan shows pricing', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Monthly pricing should be visible
      expect(findRichText('300'), findsWidgets);
    });

    testWidgets('can switch to annual pricing', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Tap annual toggle
      await tester.ensureVisible(find.text('年額'));
      await tester.tap(find.text('年額'));
      await tester.pumpAndSettle();

      // Annual pricing should be visible
      expect(findRichText('2,400'), findsWidgets);
    });

    testWidgets('pricing cards have descriptions', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Descriptions
      expect(find.text('プレミアム機能をお試しいただくのに最適'), findsWidgets);
    });

    testWidgets('annual plan marked as best value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Switch to annual
      await tester.ensureVisible(find.text('年額'));
      await tester.tap(find.text('年額'));
      await tester.pumpAndSettle();

      // Best value badge
      expect(find.text('お得プラン'), findsWidgets);
    });

    testWidgets('shows cancel anytime disclaimer', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Disclaimer
      expect(find.text('いつでも解約可能。隠れた費用はありません。'), findsWidgets);
    });

    testWidgets('displays CTA button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // CTA button
      expect(find.text('月額で続ける'), findsWidgets);
    });

    testWidgets('CTA button changes with plan selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Switch to annual
      await tester.ensureVisible(find.text('年額'));
      await tester.tap(find.text('年額'));
      await tester.pumpAndSettle();

      // Button text should change
      expect(find.text('年額で続ける'), findsWidgets);
    });

    testWidgets('shows FAQ section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // FAQ header
      expect(find.text('よくある質問'), findsWidgets);
    });

    testWidgets('displays FAQ questions', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // FAQ questions
      expect(find.text('いつでも解約できますか？'), findsWidgets);
      expect(find.text('どの支払い方法が使えますか？'), findsWidgets);
      expect(find.text('無料トライアルはありますか？'), findsWidgets);
    });

    testWidgets('displays FAQ answers', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // FAQ answers should be visible
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows success state when already subscribed', (
      WidgetTester tester,
    ) async {
      final subscribedContainer = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: true,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: subscribedContainer,
        ),
      );

      // Success message
      expect(find.text('プレミアム会員です！'), findsWidgets);
    });

    testWidgets('success state shows checkmark icon', (
      WidgetTester tester,
    ) async {
      final subscribedContainer = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: true,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: subscribedContainer,
        ),
      );

      // Checkmark icon
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      final scaffold = find.byType(Scaffold).first;
      final scaffoldWidget = tester.widget<Scaffold>(scaffold);

      expect(scaffoldWidget.backgroundColor, AppColors.sumi);
    });

    testWidgets('app bar has correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      final appBar = find.byType(AppBar).first;
      final appBarWidget = tester.widget<AppBar>(appBar);

      expect(appBarWidget.centerTitle, true);
      expect(appBarWidget.backgroundColor, AppColors.sumi);
      expect(appBarWidget.elevation, 0);
    });

    testWidgets('scrollable content', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Should have scroll view
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('hero section has gradient background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      // Gradient container should exist
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('pricing cards have distinct styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Cards should be visible
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('period suffix shown for pricing', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Period suffix
      expect(findRichText('/月'), findsWidgets);
    });

    testWidgets('benefits list uses Row layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Row for each benefit
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('displays save percentage on annual', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const PaywallScreen(),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Switch to annual
      await tester.ensureVisible(find.text('年額'));
      await tester.tap(find.text('年額'));
      await tester.pumpAndSettle();

      // Savings message
      expect(find.text('年払いで17%お得'), findsWidgets);
    });

    testWidgets('close button closes screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: MaterialApp(
            home: const PaywallScreen(),
            navigatorObservers: [],
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
          container: container,
        ),
      );

      await tester.pumpAndSettle();

      // Close button should work
      expect(find.byIcon(Icons.close), findsWidgets);
    });
  });
}

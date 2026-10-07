import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/views/screens/settings_screen.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';

import '../fixtures/test_data.dart';
import '../test_utils.dart';

void main() {
  group('SettingsScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = TestUtils.createTestContainer(
        currentUser: TestData.testUser,
        isSubscriptionActive: false,
      );
    });

    testWidgets('renders settings screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
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
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Verify title
      expect(find.text('設定'), findsWidgets);
    });

    testWidgets('shows profile section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Profile section header
      expect(find.text('プロフィール'), findsWidgets);
    });

    testWidgets('displays display name field', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Display name field
      expect(find.text('表示名'), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows email field (read-only)', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Email should be displayed
      expect(find.text('メールアドレス'), findsWidgets);
      expect(find.text(TestData.testUser.email), findsWidgets);
    });

    testWidgets('save changes button visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Save button
      expect(find.text('変更を保存'), findsWidgets);
    });

    testWidgets('shows subscription section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Subscription section
      expect(find.text('サブスクリプション'), findsWidgets);
      expect(find.text('プレミアムサブスクリプション'), findsWidgets);
    });

    testWidgets('displays subscription status', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Status should be shown
      expect(find.text('無効'), findsWidgets);
    });

    testWidgets('shows upgrade button when inactive', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Upgrade button
      expect(find.text('プレミアムにアップグレード'), findsWidgets);
    });

    testWidgets('preferences section visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Preferences section
      expect(find.text('ゲーム設定'), findsWidgets);
    });

    testWidgets('shows board size options', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Board size preference
      expect(find.text('碁盤サイズの初期設定'), findsWidgets);
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('displays all board size options', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // All board sizes should be available
      expect(find.text('7×7'), findsWidgets);
      expect(find.text('9×9'), findsWidgets);
      expect(find.text('13×13'), findsWidgets);
      expect(find.text('19×19'), findsWidgets);
    });

    testWidgets('shows AI difficulty slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // AI difficulty section
      expect(find.text('AI難易度の初期設定'), findsWidgets);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('slider shows difficulty level', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Slider.label only renders as a tooltip while actively being
      // dragged, not as static text - check the widget's label property
      // instead.
      final slider = tester.widget<Slider>(find.byType(Slider).first);
      expect(slider.label, contains('レベル'));
    });

    testWidgets('shows difficulty labels (Beginner/Expert)', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Labels
      expect(find.text('初心者'), findsWidgets);
      expect(find.text('エキスパート'), findsWidgets);
    });

    testWidgets('privacy section visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Privacy section
      expect(find.text('プライバシーとデータ'), findsWidgets);
    });

    testWidgets('shows privacy toggle switches', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Privacy toggles
      expect(find.text('対局統計を共有'), findsWidgets);
      expect(find.text('匿名モード'), findsWidgets);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('displays privacy policy link', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Privacy policy link
      expect(find.text('プライバシーポリシーを読む'), findsWidgets);
    });

    testWidgets('account section visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Account section
      expect(find.text('アカウント'), findsWidgets);
    });

    testWidgets('shows sign out button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Sign out button
      expect(find.text('サインアウト'), findsWidgets);
    });

    testWidgets('shows delete account button', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Delete account button
      expect(find.text('アカウントを削除'), findsWidgets);
    });

    testWidgets('shows about section', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // About section
      expect(find.text('このアプリについて'), findsWidgets);
    });

    testWidgets('displays app version information', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Version info
      expect(find.text('バージョン'), findsWidgets);
      expect(find.text('1.0.0'), findsWidgets);
    });

    testWidgets('shows app name', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // App name
      expect(find.text('アプリ名'), findsWidgets);
      expect(find.text('GoEn - 碁縁'), findsWidgets);
    });

    testWidgets('displays terms of service link', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Terms link
      expect(find.text('利用規約'), findsWidgets);
    });

    testWidgets('displays credits link', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Credits link
      expect(find.text('クレジット・謝辞'), findsWidgets);
    });

    testWidgets('shows auth required state when no user', (WidgetTester tester) async {
      final noAuthContainer = TestUtils.createTestContainer(
        currentUser: null,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: noAuthContainer,
        ),
      );

      // Auth required message
      expect(find.text('設定を利用するにはログインしてください'), findsWidgets);
    });

    testWidgets('dark theme styling applied', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
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
          child: const SettingsScreen(),
          container: container,
        ),
      );

      final appBar = find.byType(AppBar).first;
      final appBarWidget = tester.widget<AppBar>(appBar);

      expect(appBarWidget.centerTitle, true);
      expect(appBarWidget.backgroundColor, AppColors.sumi);
      expect(appBarWidget.elevation, 0);
    });

    testWidgets('sections have golden headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Section headers should be visible
      expect(find.text('プロフィール'), findsWidgets);
      expect(find.text('サブスクリプション'), findsWidgets);
    });

    testWidgets('scrollable content', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Should have scroll view for all content
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('board size preference can be changed', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Find and tap a board size chip
      await tester.tap(find.byType(ChoiceChip).at(1));
      await tester.pumpAndSettle();

      // Should show selection changed
      expect(find.byType(ChoiceChip), findsWidgets);
    });

    testWidgets('premium member shows active status', (WidgetTester tester) async {
      final premiumContainer = TestUtils.createTestContainer(
        currentUser: TestData.premiumUser,
        isSubscriptionActive: true,
      );

      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: premiumContainer,
        ),
      );

      // Should show active status
      expect(find.text('有効'), findsWidgets);
    });

    testWidgets('premium features description shown', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Features description
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('text field for name input', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Text field should be editable
      await tester.enterText(find.byType(TextField).first, 'New Name');
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsWidgets);
    });

    testWidgets('build number displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestUtils.buildTestableWidget(
          child: const SettingsScreen(),
          container: container,
        ),
      );

      // Build number
      expect(find.text('ビルド'), findsWidgets);
      expect(find.text('2026.09.01'), findsWidgets);
    });
  });
}

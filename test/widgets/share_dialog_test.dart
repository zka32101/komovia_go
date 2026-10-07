import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/views/widgets/index.dart';

void main() {
  group('ShareDialog Widget', () {
    testWidgets('renders share dialog correctly', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('シェア先を選択'), findsOneWidget);
      expect(find.text('X (Twitter)'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('LINE'), findsOneWidget);
      expect(find.text('クリップボードにコピー'), findsOneWidget);
    });

    testWidgets('displays share content preview', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('プレビュー'), findsOneWidget);
      expect(find.text('テストシェア'), findsWidgets);
    });

    testWidgets('close button dismisses dialog', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(find.text('シェア先を選択'), findsNothing);
    });

    testWidgets('platform buttons callback is called', (WidgetTester tester) async {
      var callbackPlatform = SocialPlatform.twitter;
      var callbackCalled = false;

      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (platform) {
                        callbackPlatform = platform;
                        callbackCalled = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Twitter button
      await tester.tap(find.text('X (Twitter)'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(callbackCalled, isTrue);
      expect(callbackPlatform, equals(SocialPlatform.twitter));
    });

    testWidgets('all platform buttons are present', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('X (Twitter)'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('LINE'), findsOneWidget);
      expect(find.text('クリップボードにコピー'), findsOneWidget);
    });

    testWidgets('platform buttons have correct icons', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'テストシェア',
        hashtags: '#碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify at least some icons are present
      expect(find.byIcon(Icons.favorite), findsWidgets); // Twitter icon
      expect(find.byIcon(Icons.arrow_forward_ios), findsWidgets); // Arrow icons
    });

    testWidgets('handles long preview text', (WidgetTester tester) async {
      final content = ShareContent(
        text: 'これは非常に長いテキストです。' * 20,
        hashtags: '#碁 #Go #碁縁 #AI碁',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: tester.element(find.byType(ElevatedButton)),
                    builder: (_) => ShareDialog(
                      content: content,
                      onShare: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog should still render correctly with long text
      expect(find.text('プレビュー'), findsOneWidget);
    });
  });
}

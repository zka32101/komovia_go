import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/firebase_options.dart';

void main() {
  group('Firebase Configuration', () {
    test('Android Firebase options should have valid app ID', () {
      final options = DefaultFirebaseOptions.android;

      // Check that appId is not a placeholder
      expect(options.appId, isNotEmpty);
      expect(options.appId, isNotNull);

      // appId should contain Android identifier
      expect(
        options.appId,
        matches(RegExp(r'1:\d+:android:[a-f0-9]+')),
        reason: 'App ID should match pattern: 1:PROJECT_ID:android:APP_CODE',
      );
    });

    test('Android Firebase options should have API key', () {
      final options = DefaultFirebaseOptions.android;

      expect(options.apiKey, isNotEmpty);
      expect(options.apiKey, isNot('ANDROID_API_KEY_TO_BE_CONFIGURED'));
    });

    test('Android Firebase options should have messaging sender ID', () {
      final options = DefaultFirebaseOptions.android;

      expect(options.messagingSenderId, isNotEmpty);
      expect(options.messagingSenderId, isNot('000000000000'));
    });

    test('Android Firebase options should have valid project ID', () {
      final options = DefaultFirebaseOptions.android;

      expect(options.projectId, equals('goen-29686'));
    });

    test('iOS Firebase options should have valid app ID', () {
      final options = DefaultFirebaseOptions.ios;

      // Check that appId is not a placeholder
      expect(options.appId, isNotEmpty);
      expect(options.appId, isNotNull);

      // appId should contain iOS identifier
      expect(
        options.appId,
        matches(RegExp(r'1:\d+:ios:[a-f0-9]+')),
        reason: 'App ID should match pattern: 1:PROJECT_ID:ios:APP_CODE',
      );
    });

    test('Web Firebase options should have valid app ID', () {
      final options = DefaultFirebaseOptions.web;

      expect(options.appId, isNotEmpty);
      expect(options.appId, matches(RegExp(r'1:\d+:web:[a-f0-9]+')));
    });

    test(
      'Android points at the real Firebase project; other platforms are '
      'not configured yet',
      () {
        // Android was switched to the real goen-29686 project; iOS/web/macOS
        // still carry the goen-project placeholder from before
        // `flutterfire configure` was run for those platforms.
        expect(
          DefaultFirebaseOptions.android.projectId,
          equals('goen-29686'),
        );
        expect(DefaultFirebaseOptions.ios.projectId, equals('goen-project'));
        expect(DefaultFirebaseOptions.web.projectId, equals('goen-project'));
        expect(
          DefaultFirebaseOptions.macos.projectId,
          equals('goen-project'),
        );
      },
    );
  });
}

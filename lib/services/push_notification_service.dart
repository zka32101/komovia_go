import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Handles a push notification that arrives while the app is fully
/// terminated or backgrounded. The platform runs this in a separate,
/// isolated background isolate with no access to any state `main()` built
/// (no Riverpod container, no signed-in user) — it must be a top-level (or
/// static) function, and `vm:entry-point` keeps release-mode tree-shaking
/// from stripping it since nothing in the normal call graph reaches it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  _logger.i('Background FCM message received: ${message.messageId}');
}

/// Thin wrapper around the `firebase_messaging` singleton so callers (and
/// tests) don't depend on the plugin directly.
class PushNotificationService {
  final FirebaseMessaging _messaging;

  PushNotificationService([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Requests notification permission (a no-op returning already-granted on
  /// platforms/OS versions that don't ask). Returns whether the app may
  /// show notifications (authorized or provisional).
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Messages received while the app is in the foreground. The platform
  /// does NOT show a system-tray notification for these automatically —
  /// callers are responsible for reacting to them (e.g. refreshing an
  /// in-app unread badge).
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}

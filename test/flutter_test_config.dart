import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file under `test/`.
///
/// Many widgets/services read `FirebaseAnalytics.instance` /
/// `FirebaseFirestore.instance` (directly, not via an injected mock) during
/// `initState`/construction, and those `.instance` getters throw
/// `[core/no-app] No Firebase App '[DEFAULT]' has been created` unless a
/// default app already exists — which never happens in a plain `flutter
/// test` process, since `main()` (where `Firebase.initializeApp()` normally
/// runs) is never invoked. Mocking the platform channel and initializing a
/// fake default app here makes that call succeed everywhere without every
/// test needing to know about it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  await testMain();
}

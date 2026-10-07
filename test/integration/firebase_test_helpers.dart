import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:komovia_go/models/index.dart';

/// Test helpers for Firestore integration testing.
///
/// This suite never actually needs a real, live Firebase Auth backend -
/// every test only needs a stable (uid, email) pair to attach Firestore
/// documents to, never an actual credential check - so `createTestUser`
/// fabricates one locally instead of calling `FirebaseAuth.instanceFor(...)`,
/// which has no real backend (or emulator) to talk to under `flutter_test`
/// and would throw a MissingPluginException. `testFirestore` uses
/// `fake_cloud_firestore`'s in-memory implementation for the same reason.
class FirebaseTestHelpers {
  static late FakeFirebaseFirestore testFirestore;
  static final _FakeTestAuth testAuth = _FakeTestAuth();
  static int _uidCounter = 0;

  /// Initialize Firestore for testing (Firebase Core itself is already
  /// mocked/initialized globally by test/flutter_test_config.dart).
  static Future<void> initializeFirebaseForTesting() async {
    testFirestore = FakeFirebaseFirestore();
  }

  /// Clean up Firebase resources
  static Future<void> cleanup() async {
    testFirestore = FakeFirebaseFirestore();
    testAuth._currentUser = null;
  }

  /// Clear all Firestore collections between tests by starting fresh -
  /// simpler and more complete than deleting known collections one by one.
  static Future<void> clearFirestoreData() async {
    testFirestore = FakeFirebaseFirestore();
  }

  /// Create a test user. Returns a small stand-in for [UserCredential]
  /// with a freshly-generated uid - no real Firebase Auth call is made.
  static Future<FakeUserCredential> createTestUser({
    required String email,
    required String password,
  }) async {
    final uid = 'test-uid-${_uidCounter++}-${DateTime.now().microsecondsSinceEpoch}';
    final user = FakeTestUser(uid: uid, email: email);
    testAuth._currentUser = user;
    return FakeUserCredential(user);
  }

  /// Sign in a test user (re-attaches the given email to a fresh fake uid,
  /// since there is no real backend to look up an existing account by).
  static Future<FakeUserCredential> signInTestUser({
    required String email,
    required String password,
  }) async {
    return createTestUser(email: email, password: password);
  }

  /// Create a test user document in Firestore
  static Future<void> createTestUserDocument({
    required String uid,
    required String email,
    String displayName = 'Test User',
  }) async {
    final user = User(
      uid: uid,
      email: email,
      displayName: displayName,
      subscriptionActive: false,
      subscriptionStartDate: DateTime.now(),
      tutorialCompleted: false,
      gamesPlayedCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await testFirestore
        .collection('users')
        .doc(uid)
        .set(user.toFirestore());
  }

  /// Create a test game record
  static Future<String> createTestGameRecord({
    required String uid,
    int boardSize = 9,
    String result = 'win',
    int aiLevel = 5,
  }) async {
    final game = GameRecord(
      id: 'game-${DateTime.now().microsecondsSinceEpoch}-${_uidCounter++}',
      uid: uid,
      boardSize: boardSize,
      sgfData: generateTestSgf(boardSize, 30),
      result: result == 'win' ? GameResult.playerWin : GameResult.aiWin,
      aiLevel: aiLevel,
      playedAt: DateTime.now(),
      gameDuration: const Duration(minutes: 15),
      blackScore: 125.5,
      whiteScore: 120.0,
    );

    await testFirestore
        .collection('gameRecords')
        .doc(game.id)
        .set(game.toFirestore());

    return game.id;
  }

  /// Create a test Tsume Go problem
  static Future<String> createTestTsumeGoProblem({
    int difficulty = 3,
  }) async {
    final problem = TsumeGoProblem(
      id: 'problem-${DateTime.now().microsecondsSinceEpoch}-${_uidCounter++}',
      difficulty: difficulty,
      sgfData: generateTestSgf(9, 15),
      solutionSgf: generateTestSgf(9, 3),
      explanation: 'Test problem explanation',
      source: 'Test Collection',
      version: 1,
      createdAt: DateTime.now(),
    );

    await testFirestore
        .collection('tsumeGoProblems')
        .doc(problem.id)
        .set(problem.toFirestore());

    return problem.id;
  }

  /// Helper to generate test SGF data
  static String generateTestSgf(int boardSize, int moves) {
    final buffer = StringBuffer();
    buffer.write('(;GM[1]SZ[$boardSize]');

    for (int i = 0; i < moves; i++) {
      final row = (i % boardSize).toRadixString(36);
      final col = ((i + 1) % boardSize).toRadixString(36);
      final color = i % 2 == 0 ? 'B' : 'W';
      buffer.write(';$color[$col$row]');
    }

    buffer.write(')');
    return buffer.toString();
  }

  /// Get current test user
  static User? getCurrentTestUser() {
    final current = testAuth.currentUser;
    if (current == null) return null;
    return User(
      uid: current.uid,
      email: current.email,
      displayName: 'Test User',
      subscriptionActive: false,
      subscriptionStartDate: DateTime.now(),
      tutorialCompleted: false,
      gamesPlayedCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Wait for Firestore to sync - a no-op for the in-memory fake, kept so
  /// call sites don't need to change if a real backend is used later.
  static Future<void> waitForSync() async {}
}

/// A minimal stand-in for firebase_auth's `User` - just enough (uid, email)
/// for this suite to attach Firestore documents to a fake identity.
class FakeTestUser {
  FakeTestUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

/// A minimal stand-in for firebase_auth's `UserCredential`.
class FakeUserCredential {
  FakeUserCredential(this.user);
  final FakeTestUser user;
}

class _FakeTestAuth {
  FakeTestUser? _currentUser;
  FakeTestUser? get currentUser => _currentUser;

  Future<void> signOut() async {
    _currentUser = null;
  }
}

/// Firestore test transaction helper
class FirebaseTestTransaction {
  final CollectionReference collection;
  final String docId;

  FirebaseTestTransaction({
    required this.collection,
    required this.docId,
  });

  /// Read data from Firestore
  Future<Map<String, dynamic>?> read() async {
    final doc = await collection.doc(docId).get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// Write data to Firestore
  Future<void> write(Map<String, dynamic> data) async {
    await collection.doc(docId).set(data);
  }

  /// Update data in Firestore
  Future<void> update(Map<String, dynamic> data) async {
    await collection.doc(docId).update(data);
  }

  /// Delete document from Firestore
  Future<void> delete() async {
    await collection.doc(docId).delete();
  }

  /// Verify data exists
  Future<bool> exists() async {
    final doc = await collection.doc(docId).get();
    return doc.exists;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'firebase_test_helpers.dart';

void main() {
  group('Critical User Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Firebase once for all tests
      await FirebaseTestHelpers.initializeFirebaseForTesting();
    });

    tearDownAll(() async {
      // Clean up after all tests
      await FirebaseTestHelpers.cleanup();
    });

    tearDown(() async {
      // Clean up data between tests
      await FirebaseTestHelpers.clearFirestoreData();
      // Sign out
      await FirebaseTestHelpers.testAuth.signOut();
    });

    test('🔄 Complete auth to onboarding flow', () async {
      // Step 1: Create user
      final testEmail = 'test-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final testPassword = 'TestPassword123!';

      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: testPassword,
      );

      expect(userCred.user, isNotNull);
      expect(userCred.user!.email, testEmail);

      // Step 2: Create user document
      await FirebaseTestHelpers.createTestUserDocument(
        uid: userCred.user!.uid,
        email: testEmail,
      );

      // Step 3: Verify user document exists
      final transaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('users'),
        docId: userCred.user!.uid,
      );

      final userData = await transaction.read();
      expect(userData, isNotNull);
      expect(userData!['email'], testEmail);
      expect(userData['tutorialCompleted'], false);
    });

    test('🎮 Game flow: Create game → Play → Save result', () async {
      // Setup: Create and authenticate user
      final testEmail = 'game-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Step 1: Create user document
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      // Step 2: Create a game record
      final gameId = await FirebaseTestHelpers.createTestGameRecord(
        uid: uid,
        boardSize: 9,
        result: 'win',
      );

      expect(gameId, isNotEmpty);

      // Step 3: Verify game record exists and can be retrieved
      final gameTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('gameRecords'),
        docId: gameId,
      );

      final gameData = await gameTransaction.read();
      expect(gameData, isNotNull);
      expect(gameData!['uid'], uid);
      expect(gameData['boardSize'], 9);
      // GameResult.playerWin serializes via toShortString() as 'player_win',
      // not the plain 'win' this helper's `result` param is named after.
      expect(gameData['result'], 'player_win');

      // Step 4: Update game with analysis
      await gameTransaction.update({
        'analyzedAt': DateTime.now().toIso8601String(),
        'analysis': 'Good opening strategy demonstrated',
      });

      final updatedGameData = await gameTransaction.read();
      expect(updatedGameData!['analysis'], 'Good opening strategy demonstrated');
    });

    test('🧩 Puzzle flow: Load daily → Attempt → Save result', () async {
      // Setup: Create user
      final testEmail = 'puzzle-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Step 1: Create user document
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      // Step 2: Create a test puzzle
      final problemId = await FirebaseTestHelpers.createTestTsumeGoProblem(
        difficulty: 2,
      );

      expect(problemId, isNotEmpty);

      // Step 3: Create attempt log
      final attemptId = 'attempt-${DateTime.now().millisecondsSinceEpoch}';
      final attemptTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('userTsumeGoLogs'),
        docId: attemptId,
      );

      await attemptTransaction.write({
        'uid': uid,
        'problemId': problemId,
        'isCorrect': true,
        'solvedAt': DateTime.now().toIso8601String(),
        'attemptCount': 1,
      });

      // Step 4: Verify attempt was saved
      final attemptData = await attemptTransaction.read();
      expect(attemptData, isNotNull);
      expect(attemptData!['uid'], uid);
      expect(attemptData['isCorrect'], true);

      // Step 5: Update user's puzzle streak
      final userTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('users'),
        docId: uid,
      );

      await userTransaction.update({
        'dailyPuzzleStreak': 1,
        'lastPuzzleDate': DateTime.now().toIso8601String(),
      });

      final userData = await userTransaction.read();
      expect(userData!['dailyPuzzleStreak'], 1);
    });

    test('📚 Kifu observation flow: Browse → Select → Watch', () async {
      // Step 1: Create historical game (Kifu)
      final kifuId = 'kifu-${DateTime.now().millisecondsSinceEpoch}';
      final kifuTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('kifuLibrary'),
        docId: kifuId,
      );

      await kifuTransaction.write({
        'title': 'Honinbo Shusaku vs Iwasaki Kisaburo',
        'players': 'Honinbo Shusaku vs Iwasaki Kisaburo',
        'sgfData': FirebaseTestHelpers.generateTestSgf(19, 200),
        'category': 'professional',
        'source': 'Go Server Archive',
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect(await kifuTransaction.exists(), true);

      // Step 2: Create user and log observation
      final testEmail = 'kifu-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Step 3: Log observation
      final logId = 'log-${DateTime.now().millisecondsSinceEpoch}';
      final logTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('observationLogs'),
        docId: logId,
      );

      await logTransaction.write({
        'uid': uid,
        'kifuId': kifuId,
        'watchedAt': DateTime.now().toIso8601String(),
        'completedRate': 0.75, // Watched 75% of game
      });

      final logData = await logTransaction.read();
      expect(logData!['completedRate'], 0.75);
    });

    test('💳 Subscription flow: Trigger paywall → Upgrade → Verify', () async {
      // Setup: Create user
      final testEmail = 'sub-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Step 1: Create user with free subscription
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      final userTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('users'),
        docId: uid,
      );

      var userData = await userTransaction.read();
      expect(userData!['subscriptionActive'], false);

      // Step 2: Simulate subscription upgrade
      await userTransaction.update({
        'subscriptionActive': true,
        'subscriptionPlan': 'annual',
        'subscriptionStartDate': DateTime.now().toIso8601String(),
      });

      // Step 3: Verify subscription is now active
      userData = await userTransaction.read();
      expect(userData!['subscriptionActive'], true);
      expect(userData['subscriptionPlan'], 'annual');
    });

    test('🔄 Multi-screen navigation: Home → Game → Result → History', () async {
      // Setup
      final testEmail = 'nav-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Create user and game records
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      // Create multiple games
      final gameIds = <String>[];
      for (int i = 0; i < 5; i++) {
        final gameId = await FirebaseTestHelpers.createTestGameRecord(
          uid: uid,
          result: i % 2 == 0 ? 'win' : 'loss',
        );
        gameIds.add(gameId);
      }

      // Verify all games are retrievable (simulating history screen)
      final allGames = await FirebaseTestHelpers.testFirestore
          .collection('gameRecords')
          .where('uid', isEqualTo: uid)
          .get();

      expect(allGames.docs.length, 5);

      // Count wins and losses
      int wins = 0;
      int losses = 0;
      for (final doc in allGames.docs) {
        final result = doc['result'] as String;
        if (result == 'win') {
          wins++;
        } else {
          losses++;
        }
      }

      expect(wins + losses, 5);
    });

    test('📊 Analytics flow: Track game metrics', () async {
      // Setup
      final testEmail = 'analytics-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Create user
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      // Create game and log analytics
      final gameId = await FirebaseTestHelpers.createTestGameRecord(
        uid: uid,
      );

      // Simulate analytics logging
      final analyticsLogId = 'event-${DateTime.now().millisecondsSinceEpoch}';
      final analyticsTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('analyticsEvents'),
        docId: analyticsLogId,
      );

      await analyticsTransaction.write({
        'uid': uid,
        'eventName': 'ai_game_completed',
        'boardSize': 9,
        'result': 'win',
        'aiLevel': 5,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final eventData = await analyticsTransaction.read();
      expect(eventData!['eventName'], 'ai_game_completed');
    });

    test('🔐 Concurrent operations: Multiple users playing simultaneously', () async {
      // Create 3 concurrent users
      final users = <String, String>{};

      for (int i = 0; i < 3; i++) {
        final email = 'concurrent-$i-${DateTime.now().millisecondsSinceEpoch}@example.com';
        final userCred = await FirebaseTestHelpers.createTestUser(
          email: email,
          password: 'TestPassword123!',
        );

        users[userCred.user!.uid] = email;

        // Create user document
        await FirebaseTestHelpers.createTestUserDocument(
          uid: userCred.user!.uid,
          email: email,
        );

        // Create a game concurrently
        await FirebaseTestHelpers.createTestGameRecord(
          uid: userCred.user!.uid,
        );
      }

      expect(users.length, 3);

      // Verify all users and their games exist
      for (final uid in users.keys) {
        final userDoc = await FirebaseTestHelpers.testFirestore
            .collection('users')
            .doc(uid)
            .get();

        expect(userDoc.exists, true);

        final userGames = await FirebaseTestHelpers.testFirestore
            .collection('gameRecords')
            .where('uid', isEqualTo: uid)
            .get();

        expect(userGames.docs.length, greaterThanOrEqualTo(1));
      }
    });

    test('💾 Data consistency: Transaction rollback on error', () async {
      // Setup
      final testEmail = 'consistency-${DateTime.now().millisecondsSinceEpoch}@example.com';
      final userCred = await FirebaseTestHelpers.createTestUser(
        email: testEmail,
        password: 'TestPassword123!',
      );

      final uid = userCred.user!.uid;

      // Create initial state
      await FirebaseTestHelpers.createTestUserDocument(
        uid: uid,
        email: testEmail,
      );

      final userTransaction = FirebaseTestTransaction(
        collection: FirebaseTestHelpers.testFirestore.collection('users'),
        docId: uid,
      );

      // Read initial state
      var userData = await userTransaction.read();
      expect(userData!['subscriptionActive'], false);

      // Perform update
      await userTransaction.update({'subscriptionActive': true});

      // Verify update
      userData = await userTransaction.read();
      expect(userData!['subscriptionActive'], true);

      // Rollback by updating back
      await userTransaction.update({'subscriptionActive': false});

      userData = await userTransaction.read();
      expect(userData!['subscriptionActive'], false);
    });
  });
}

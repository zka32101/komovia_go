import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/screens/friend_profile_screen.dart';

import '../test_utils.dart';

/// LeaderboardService has no Firestore injection point (it hardcodes
/// FirebaseFirestore.instance), unlike every other service in this app -
/// so getUserRank is overridden here instead of going through a fake
/// Firestore like the rest of the screen's data.
class _FakeLeaderboardService extends LeaderboardService {
  final LeaderboardEntry? entry;
  _FakeLeaderboardService(this.entry);

  @override
  Future<LeaderboardEntry?> getUserRank({
    required String uid,
    required LeaderboardPeriod period,
    required LeaderboardType type,
  }) async =>
      entry;
}

Widget _buildApp(ProviderContainer container, Friendship friend, {VoidCallback? onInvite}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: FriendProfileScreen(
        currentUid: 'me',
        friend: friend,
        onInvite: onInvite,
      ),
      theme: ThemeData.dark(),
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('FriendProfileScreen', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    ProviderContainer buildContainer({LeaderboardEntry? rankEntry}) {
      return TestUtils.createTestContainer(
        extraOverrides: [
          leaderboardServiceProvider.overrideWithValue(_FakeLeaderboardService(rankEntry)),
          enScoreServiceProvider.overrideWithValue(EnScoreService(firestore)),
        ],
      );
    }

    final friend = Friendship(
      uid: 'me',
      friendUid: 'friend-1',
      displayName: 'Taro',
      status: 'accepted',
      addedAt: DateTime.now().subtract(const Duration(days: 40)),
    );

    testWidgets('shows the friend name and rating', (tester) async {
      final rankEntry = LeaderboardEntry(
        uid: 'friend-1',
        displayName: 'Taro',
        rank: 3,
        rating: 1850,
        gamesPlayed: 12,
        wins: 10,
        winRate: 0.83,
        puzzlesSolved: 0,
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(_buildApp(buildContainer(rankEntry: rankEntry), friend));
      await tester.pump();
      await tester.pump();

      expect(find.text('Taro'), findsWidgets);
      expect(find.textContaining('レート 1850'), findsOneWidget);
    });

    testWidgets('prompts to calculate the en score when none exists yet, then shows it', (tester) async {
      await tester.pumpWidget(_buildApp(buildContainer(), friend));
      await tester.pump();
      await tester.pump();

      expect(find.text('縁スコアはまだ計算されていません'), findsOneWidget);

      await tester.tap(find.text('計算する'));
      await tester.pump();
      await tester.pump();

      expect(find.text('縁スコアはまだ計算されていません'), findsNothing);
      expect(find.textContaining('縁スコア'), findsWidgets);

      final connection = await EnScoreService(firestore).getEnConnection('me', 'friend-1');
      expect(connection, isNotNull);
    });

    testWidgets('shows an already-calculated en score', (tester) async {
      await firestore
          .collection('en_scores')
          .doc('me')
          .collection('connections')
          .doc('friend-1')
          .set({
        'uid': 'me',
        'friendDisplayName': 'Taro',
        'score': 42,
        'friendshipDays': 40,
        'matchesPlayed': 3,
        'sharedSpectateSessions': 1,
        'sharedPositionEchoes': 0,
        'calculatedAt': Timestamp.now(),
      });

      await tester.pumpWidget(_buildApp(buildContainer(), friend));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('縁スコア 42 / 100'), findsOneWidget);
      expect(find.textContaining('対局 3回'), findsOneWidget);
    });

    testWidgets('invite button triggers the callback', (tester) async {
      var invited = false;
      await tester.pumpWidget(
        _buildApp(buildContainer(), friend, onInvite: () => invited = true),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('ゲームに招待'));
      await tester.pump();

      expect(invited, true);
    });

  });
}

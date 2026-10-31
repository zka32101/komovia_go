import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/config/avatar_frames.dart';

void main() {
  group('catalog', () {
    test('has unique ids and spans every tier', () {
      final ids = kGoAvatarFrames.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(kGoAvatarFrames.length, inInclusiveRange(8, 12));
      expect(kGoAvatarFrames.map((f) => f.tier).toSet(),
          equals(FrameTier.values.toSet()));
    });

    test('sticky ids all exist in the catalog', () {
      for (final id in kStickyFrameIds) {
        expect(avatarFrameById(id), isNotNull);
      }
    });
  });

  group('computeUnlockedFrameIds', () {
    test('nothing is unlocked for a brand-new user', () {
      expect(computeUnlockedFrameIds(const FrameStats()), isEmpty);
    });

    test('rank frames follow the go_rank dan boundaries', () {
      expect(computeUnlockedFrameIds(const FrameStats(rating: 1999)),
          isNot(contains(FrameIds.shodan)));
      final at5dan = computeUnlockedFrameIds(const FrameStats(rating: 2400));
      expect(at5dan, containsAll([FrameIds.shodan, FrameIds.godan]));
      expect(at5dan, isNot(contains(FrameIds.kudan)));
      expect(computeUnlockedFrameIds(const FrameStats(rating: 2800)),
          contains(FrameIds.kudan));
    });

    test('games-played thresholds', () {
      expect(computeUnlockedFrameIds(const FrameStats(gamesPlayed: 9)), isEmpty);
      expect(computeUnlockedFrameIds(const FrameStats(gamesPlayed: 100)),
          {FrameIds.games10, FrameIds.games100});
      expect(computeUnlockedFrameIds(const FrameStats(gamesPlayed: 1000)),
          contains(FrameIds.games1000));
    });

    test('tournament, wins, streak and En score', () {
      final s = computeUnlockedFrameIds(const FrameStats(
          tournamentWins: 1, wins: 100, tsumegoStreak: 3, maxEnScore: 100));
      expect(s, containsAll([
        FrameIds.tournamentChampion,
        FrameIds.wins100,
        FrameIds.tsumegoStreak3,
        FrameIds.enScore100,
      ]));
      expect(s, isNot(contains(FrameIds.tsumegoStreak30)));
    });

    test('sticky frames survive the stat dropping; live ones do not persist',
        () {
      final s = computeUnlockedFrameIds(const FrameStats(
        earnedFrameIds: {FrameIds.tsumegoStreak3, FrameIds.kudan, 'bogus'},
      ));
      expect(s, {FrameIds.tsumegoStreak3});
    });
  });

  group('resolveDisplayedFrame', () {
    test('null / unknown / locked selections render no frame', () {
      expect(resolveDisplayedFrame(null, {FrameIds.shodan}), isNull);
      expect(resolveDisplayedFrame('nope', {'nope'}), isNull);
      expect(resolveDisplayedFrame(FrameIds.kudan, {FrameIds.shodan}), isNull);
    });

    test('an unlocked selection renders', () {
      expect(resolveDisplayedFrame(FrameIds.shodan, {FrameIds.shodan})?.id,
          FrameIds.shodan);
    });
  });

  group('FramedAvatar', () {
    testWidgets('no frame -> no ring', (t) async {
      await t.pumpWidget(const MaterialApp(home: FramedAvatar(emoji: '🦊')));
      expect(find.text('🦊'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-frame-rank_shodan')), findsNothing);
    });

    testWidgets('frame -> tier-colored ring', (t) async {
      final frame = avatarFrameById(FrameIds.shodan)!;
      await t.pumpWidget(
          MaterialApp(home: FramedAvatar(emoji: '🦊', frame: frame)));
      final box = t.widget<Container>(
          find.byKey(const ValueKey('avatar-frame-rank_shodan')));
      final border = (box.decoration as BoxDecoration).border as Border;
      expect(border.top.color, frameTierColor(FrameTier.bronze));
    });
  });
}

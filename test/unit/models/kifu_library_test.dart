import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/models/kifu_library.dart';

void main() {
  group('KifuLibrary.getDifficultyName', () {
    KifuLibrary withDifficulty(int? difficulty) => KifuLibrary(
          id: 'id',
          title: 'title',
          sgfData: '(;GM[1]SZ[9])',
          category: KifuCategory.copyrightFree,
          isPremium: false,
          source: 'Public Domain',
          createdAt: DateTime.now(),
          difficulty: difficulty,
        );

    test('returns null when unrated', () {
      expect(withDifficulty(null).getDifficultyName(), isNull);
    });

    test('returns the matching star rating for 1 through 5', () {
      expect(withDifficulty(1).getDifficultyName(), equals('★☆☆☆☆'));
      expect(withDifficulty(2).getDifficultyName(), equals('★★☆☆☆'));
      expect(withDifficulty(3).getDifficultyName(), equals('★★★☆☆'));
      expect(withDifficulty(4).getDifficultyName(), equals('★★★★☆'));
      expect(withDifficulty(5).getDifficultyName(), equals('★★★★★'));
    });

    test('returns null for an out-of-range value', () {
      expect(withDifficulty(0).getDifficultyName(), isNull);
      expect(withDifficulty(6).getDifficultyName(), isNull);
    });
  });

  group('KifuLibrary Firestore round-trip', () {
    test('toFirestore/fromFirestore preserves a set difficulty', () {
      final original = KifuLibrary(
        id: 'id',
        title: 'title',
        sgfData: '(;GM[1]SZ[9])',
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'Public Domain',
        createdAt: DateTime(2026, 1, 1),
        difficulty: 3,
      );

      final data = original.toFirestore();
      expect(data['difficulty'], equals(3));
    });

    test('toFirestore writes null when unrated', () {
      final original = KifuLibrary(
        id: 'id',
        title: 'title',
        sgfData: '(;GM[1]SZ[9])',
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'Public Domain',
        createdAt: DateTime(2026, 1, 1),
      );

      final data = original.toFirestore();
      expect(data['difficulty'], isNull);
    });

    test('a real write/read round-trip through Firestore preserves difficulty', () async {
      final firestore = FakeFirebaseFirestore();
      final original = KifuLibrary(
        id: 'ignored-until-written',
        title: 'title',
        sgfData: '(;GM[1]SZ[9])',
        category: KifuCategory.copyrightFree,
        isPremium: false,
        source: 'Public Domain',
        createdAt: DateTime(2026, 1, 1),
        difficulty: 4,
      );

      final docRef = firestore.collection('kifuLibrary').doc('kifu-1');
      await docRef.set(original.toFirestore());

      final snapshot = await docRef.get();
      final roundTripped = KifuLibrary.fromFirestore(snapshot);

      expect(roundTripped.difficulty, equals(4));
      expect(roundTripped.getDifficultyName(), equals('★★★★☆'));
    });

    test('an existing document with no difficulty field reads back as unrated', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('kifuLibrary').doc('legacy-kifu');
      // Simulates a pre-existing document written before this field existed.
      await docRef.set({
        'title': 'Legacy Game',
        'sgfData': '(;GM[1]SZ[9])',
        'category': 'copyright_free',
        'isPremium': false,
        'source': 'Public Domain',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      final snapshot = await docRef.get();
      final roundTripped = KifuLibrary.fromFirestore(snapshot);

      expect(roundTripped.difficulty, isNull);
    });
  });
}

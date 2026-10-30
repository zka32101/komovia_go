import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/fateful_move.dart';
import 'package:komovia_go/models/leaderboard_display.dart';
import 'package:komovia_go/utils/go_rank.dart';

void main() {
  group('formatGoRank', () {
    test('日本語が既定で、従来の表記を保つ', () {
      expect(formatGoRank(1200), '8級');
      expect(formatGoRank(2000), '初段');
      expect(formatGoRank(2100), '二段');
    });

    test('英語は kyu / dan で返す', () {
      expect(formatGoRank(1200, ja: false), '8 kyu');
      expect(formatGoRank(2000, ja: false), '1 dan');
      expect(formatGoRank(2100, ja: false), '2 dan');
    });

    test('級・段の上限と下限は言語によらず同じ', () {
      expect(formatGoRank(9999, ja: false), '9 dan');
      expect(formatGoRank(-9999, ja: false), '30 kyu');
    });
  });

  group('ランキングの表示名', () {
    test('期間は言語ごとに返る', () {
      expect(LeaderboardPeriod.allTime.getDisplayName(), '通算');
      expect(LeaderboardPeriod.allTime.getDisplayName(ja: false), 'All time');
    });

    test('種別は言語ごとに返る', () {
      expect(LeaderboardType.puzzles.getDisplayName(), '詰碁');
      expect(LeaderboardType.puzzles.getDisplayName(ja: false), 'Tsume-go');
    });
  });

  test('運命の一手の名前は既定が日本語、英語も返せる', () {
    expect(FatefulMoveType.tesuji.getDisplayName(), '妙手');
    expect(FatefulMoveType.tesuji.getDisplayName(ja: false), 'Tesuji');
  });
}

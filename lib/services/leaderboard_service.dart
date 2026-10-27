import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:logger/logger.dart';
import 'firestore_time.dart';

final _logger = Logger();

/// `LeaderboardEntry` has no storage dependency (see komovia_core's doc
/// comments) - converting to/from Firestore's `Timestamp` is this
/// service's own responsibility.
LeaderboardEntry _entryFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  return LeaderboardEntry.fromJson({
    ...data,
    'uid': doc.id,
    'lastUpdated': isoFromTimestamp(data['lastUpdated']),
  });
}

extension _LeaderboardEntryFirestore on LeaderboardEntry {
  Map<String, dynamic> toFirestoreFields() {
    final json = toJson()..remove('uid');
    json['lastUpdated'] = Timestamp.fromDate(lastUpdated);
    return json;
  }
}

/// 選択されたdaily/weekly/monthlyがUI上は選べるのに常に空のまま
/// だった実バグの修正: 以前は全ての書き込みが`period.toShortString()`
/// （例: 'daily'固定の1ドキュメント）を参照しており、それをリセットする
/// Cloud Functions相当の仕組みが無いまま蓄積し続けるだけだったため、
/// UIからdaily/weekly/monthlyを選ぶと実質どの期間でも同じ内容が
/// 返ってきてしまっていた（pvp_game_provider.dartの既存コメントが示す
/// ように、意図的にallTimeのみ書き込むよう回避されていた）。
/// Cloud Functionsを使わずに「期間ごとに自然にリセットされる」ようにする
/// ため、daily/weekly/monthlyは現在の日付から導出した期間キーを
/// ドキュメントIDに含める（例: 'daily_2026-10-27'/'weekly_2026-W44'/
/// 'monthly_2026-10'）。新しい期間に入ると自動的に新しいドキュメントに
/// 切り替わり、古いデータは単に読まれなくなるだけで削除の仕組みは不要。
/// allTimeは従来通り固定のドキュメントID('all_time')のまま。
String periodDocId(LeaderboardPeriod period, {DateTime? now}) {
  final current = now ?? DateTime.now();
  switch (period) {
    case LeaderboardPeriod.allTime:
      return period.toShortString();
    case LeaderboardPeriod.daily:
      return 'daily_${_yyyyMmDd(current)}';
    case LeaderboardPeriod.weekly:
      return 'weekly_${_isoWeekKey(current)}';
    case LeaderboardPeriod.monthly:
      return 'monthly_${current.year}-${current.month.toString().padLeft(2, '0')}';
  }
}

String _yyyyMmDd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// ISO 8601週番号（月曜始まり、1年の最初の木曜を含む週が第1週）。
String _isoWeekKey(DateTime d) {
  // ISO8601: その日を含む週の木曜日が属する年がISO年、木曜日からの
  // 週番号を1月1日からの日数で算出する標準的なアルゴリズム。
  final date = DateTime.utc(d.year, d.month, d.day);
  final weekday = date.weekday; // 1=Mon..7=Sun
  final thursday = date.add(Duration(days: 4 - weekday));
  final isoYear = thursday.year;
  final jan1 = DateTime.utc(isoYear, 1, 1);
  final weekNumber = ((thursday.difference(jan1).inDays) / 7).floor() + 1;
  return '$isoYear-W${weekNumber.toString().padLeft(2, '0')}';
}

/// Leaderboard データベース操作サービス
class LeaderboardService {
  final FirebaseFirestore _firestore;

  LeaderboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String leaderboardCollection = 'leaderboards';

  /// タイプごとの実際のスコアフィールド。個々の updateUserScore/
  /// incrementUserStats 呼び出しは呼び出し元ごとに独立しており、
  /// updateLeaderboard の全件バッチ再計算(呼び出し元なし)を経ずに
  /// entry.rank を正しく保つ手段がないため、rank でソートせずこの
  /// フィールドで直接ソートし、取得側でインデックスから順位を振り直す。
  String _sortFieldFor(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.puzzles:
        return 'puzzlesSolved';
      case LeaderboardType.achievements:
        return 'achievementsUnlocked';
      case LeaderboardType.tournament:
        return 'tournamentWins';
      case LeaderboardType.rating:
        return 'rating';
    }
  }

  /// ランキングを取得（期間・タイプ別）
  Future<List<LeaderboardEntry>> getLeaderboard({
    required LeaderboardPeriod period,
    required LeaderboardType type,
    int limit = 100,
  }) async {
    try {
      _logger.i('Fetching leaderboard: period=$period, type=$type');

      final query = _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString())
          .orderBy(_sortFieldFor(type), descending: true)
          .limit(limit);

      final snapshot = await query.get();
      final entries = snapshot.docs
          .map((doc) => _entryFromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Assign rank from the already-sorted query result rather than
      // trusting the stored `rank` field (see _sortFieldFor's comment).
      for (var i = 0; i < entries.length; i++) {
        entries[i] = entries[i].copyWith(rank: i + 1);
      }

      _logger.i('✅ Leaderboard fetched: ${entries.length} entries');
      return entries;
    } catch (e) {
      _logger.e('Error fetching leaderboard: $e');
      rethrow;
    }
  }

  /// ユーザーのランキングを取得
  Future<LeaderboardEntry?> getUserRank({
    required String uid,
    required LeaderboardPeriod period,
    required LeaderboardType type,
  }) async {
    try {
      _logger.i('Fetching user rank: uid=$uid, period=$period, type=$type');

      final doc = await _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString())
          .doc(uid)
          .get();

      if (!doc.exists) {
        return null;
      }

      return _entryFromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      _logger.e('Error fetching user rank: $e');
      rethrow;
    }
  }

  /// ランキングを更新（自動計算・バッチ更新）
  Future<void> updateLeaderboard({
    required LeaderboardPeriod period,
    required LeaderboardType type,
    required List<LeaderboardEntry> entries,
  }) async {
    try {
      _logger.i('Updating leaderboard: period=$period, type=$type');

      final batch = _firestore.batch();
      final collectionRef = _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString());

      // ランク順にソート
      entries.sort((a, b) => a.rank.compareTo(b.rank));

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i].copyWith(rank: i + 1);
        batch.set(collectionRef.doc(entry.uid), entry.toFirestoreFields());
      }

      await batch.commit();
      _logger.i('✅ Leaderboard updated');
    } catch (e) {
      _logger.e('Error updating leaderboard: $e');
      rethrow;
    }
  }

  /// ユーザーのスコアを更新
  Future<void> updateUserScore({
    required String uid,
    required String displayName,
    required LeaderboardPeriod period,
    required LeaderboardType type,
    required int rating,
    required int gamesPlayed,
    required int wins,
    required int puzzlesSolved,
  }) async {
    try {
      _logger.i('Updating user score: uid=$uid, rating=$rating');

      final winRate = gamesPlayed > 0 ? wins / gamesPlayed : 0.0;

      final entry = LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        rank: 0, // Will be recalculated by batch process
        rating: rating,
        gamesPlayed: gamesPlayed,
        wins: wins,
        winRate: winRate,
        puzzlesSolved: puzzlesSolved,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString())
          .doc(uid)
          .set(entry.toFirestoreFields(), SetOptions(merge: true));

      _logger.i('✅ User score updated');
    } catch (e) {
      _logger.e('Error updating user score: $e');
      rethrow;
    }
  }

  /// ユーザーの統計を安全にインクリメント/更新する。
  ///
  /// updateUserScore は毎回全フィールドをまとめて set するため、複数の
  /// 呼び出し元（PvP対局結果・詰碁の正解）が同じドキュメントの別々の
  /// フィールドだけを更新したい場合、他方が把握していないフィールドを
  /// 0で上書きしてしまう。トランザクションで現在値を読み、デルタ分だけ
  /// 加算/絶対値で更新することでこれを避ける。
  Future<void> incrementUserStats({
    required String uid,
    required String displayName,
    required LeaderboardPeriod period,
    required LeaderboardType type,
    int? newRating,
    int gamesPlayedDelta = 0,
    int winsDelta = 0,
    int puzzlesSolvedDelta = 0,
    int achievementsUnlockedDelta = 0,
    int tournamentWinsDelta = 0,
  }) async {
    try {
      _logger.i('Incrementing user stats: uid=$uid, period=$period, type=$type');

      final docRef = _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString())
          .doc(uid);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final current = snapshot.exists
            ? _entryFromDoc(snapshot as DocumentSnapshot<Map<String, dynamic>>)
            : LeaderboardEntry(
                uid: uid,
                displayName: displayName,
                rank: 0,
                rating: 1200,
                gamesPlayed: 0,
                wins: 0,
                winRate: 0.0,
                puzzlesSolved: 0,
                lastUpdated: DateTime.now(),
              );

        final gamesPlayed = current.gamesPlayed + gamesPlayedDelta;
        final wins = current.wins + winsDelta;
        final updated = current.copyWith(
          displayName: displayName,
          rating: newRating ?? current.rating,
          gamesPlayed: gamesPlayed,
          wins: wins,
          winRate: gamesPlayed > 0 ? wins / gamesPlayed : 0.0,
          puzzlesSolved: current.puzzlesSolved + puzzlesSolvedDelta,
          achievementsUnlocked:
              current.achievementsUnlocked + achievementsUnlockedDelta,
          tournamentWins: current.tournamentWins + tournamentWinsDelta,
          lastUpdated: DateTime.now(),
        );

        transaction.set(docRef, updated.toFirestoreFields());
      });

      _logger.i('✅ User stats incremented: uid=$uid');
    } catch (e) {
      _logger.e('Error incrementing user stats: $e');
      rethrow;
    }
  }

  /// 期間別ランキングをリセット
  Future<void> resetLeaderboard({
    required LeaderboardPeriod period,
    required LeaderboardType type,
  }) async {
    try {
      _logger.w('Resetting leaderboard: period=$period, type=$type');

      final snapshot = await _firestore
          .collection(leaderboardCollection)
          .doc(periodDocId(period))
          .collection(type.toShortString())
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.i('✅ Leaderboard reset');
    } catch (e) {
      _logger.e('Error resetting leaderboard: $e');
      rethrow;
    }
  }
}

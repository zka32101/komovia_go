import 'package:cloud_firestore/cloud_firestore.dart';

/// 2人のプレイヤー間のリアルタイム対局（マッチング成立後の実対局）
class PvpGame {
  final String id;
  final int boardSize;
  final String blackUid;
  final String blackDisplayName;
  final String whiteUid;
  final String whiteDisplayName;
  final List<List<int>> stones; // 0=空, 1=黒, 2=白
  final bool isBlackTurn;
  final int capturedBlack;
  final int capturedWhite;
  final int? koRow;
  final int? koCol;
  final int? lastMoveRow;
  final int? lastMoveCol;
  final int movesCount;
  final int consecutivePasses;
  final String status; // 'active', 'finished'
  final String? winnerUid;
  final String? result; // 'resignation', 'score', null(進行中)
  final double? blackScore; // 中国ルールの地合計算結果（'score'決着時のみ）
  final double? whiteScore; // コミ込み。'resignation'決着時はnull
  final String? matchId; // matching engineのMatchResult.idとの紐付け（あれば）
  final String? tournamentId; // トーナメント試合の場合の大会ID
  final String? tournamentMatchId; // トーナメント試合の場合のTournamentMatch ID
  // ライブ観戦フレンド機能用の観戦セッションID（作成時にbest-effortで
  // 紐付けられる。作成に失敗していればnullのまま — 対局自体はブロックしない）。
  final String? spectatorSessionId;
  // 時計（持ち時間 + Fischer方式の加算時間）。「NO TIMERS」方針は対局の
  // 緊張感を煽らないAI対局向けであり、オンライン対局(PvP)固有の持ち時間
  // 要望（レビュー調査で確認）とは別物 — claimAbandonmentForfeitの
  // 「放置対局の救済」と同じく、ここでも時計はPvP限定の機能として追加
  // している。mainTimeSeconds/incrementSecondsは対局設定（作成時に固定）、
  // black/whiteTimeMsはそれぞれの「現在の持ち時間バンク」(ミリ秒)、
  // turnStartedAtは現在の手番が始まった時刻 - これらからライブの残り
  // 時間を計算する（remainingMs参照）。Firestoreにはサーバー側で動く
  // 時計そのものは無いため、「相手の時間が切れた」はclaimTimeoutForfeitで
  // 相手側から申告する方式（claimAbandonmentForfeitと同じ設計）。
  final int mainTimeSeconds;
  final int incrementSeconds;
  final int blackTimeMs;
  final int whiteTimeMs;
  final DateTime? turnStartedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PvpGame({
    required this.id,
    required this.boardSize,
    required this.blackUid,
    required this.blackDisplayName,
    required this.whiteUid,
    required this.whiteDisplayName,
    required this.stones,
    required this.isBlackTurn,
    required this.capturedBlack,
    required this.capturedWhite,
    this.koRow,
    this.koCol,
    this.lastMoveRow,
    this.lastMoveCol,
    required this.movesCount,
    required this.consecutivePasses,
    required this.status,
    this.winnerUid,
    this.result,
    this.blackScore,
    this.whiteScore,
    this.matchId,
    this.tournamentId,
    this.tournamentMatchId,
    this.spectatorSessionId,
    this.mainTimeSeconds = 600,
    this.incrementSeconds = 10,
    int? blackTimeMs,
    int? whiteTimeMs,
    this.turnStartedAt,
    required this.createdAt,
    this.updatedAt,
  }) : blackTimeMs = blackTimeMs ?? mainTimeSeconds * 1000,
       whiteTimeMs = whiteTimeMs ?? mainTimeSeconds * 1000;

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  /// 現時点([now])での[forBlack]側の残り時間（ミリ秒）。手番側は
  /// turnStartedAtからの経過分を減算したライブ値、手番でない側は
  /// バンクの値そのまま。0未満にはならない。
  int remainingMs(bool forBlack, DateTime now) {
    final bank = forBlack ? blackTimeMs : whiteTimeMs;
    final isMover = forBlack == isBlackTurn;
    if (!isMover || turnStartedAt == null) return bank < 0 ? 0 : bank;
    final elapsed = now.difference(turnStartedAt!).inMilliseconds;
    final remaining = bank - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// [uid]が、相手の持ち時間が切れていることを理由に時間切れ勝ちを
  /// 申請できるか（相手が手番で、そのライブ残り時間が0の場合のみ）。
  bool canClaimTimeoutForfeit(String uid, DateTime now) {
    if (!isActive) return false;
    final color = playerColorOf(uid);
    if (color == 0) return false;
    if (isTurnOf(uid)) return false; // 自分の手番なら相手は時間切れではない
    final opponentIsBlack = !(color == 1);
    return remainingMs(opponentIsBlack, now) <= 0;
  }

  /// uidが黒番なら1、白番なら2、対局者でなければ0
  int playerColorOf(String uid) {
    if (uid == blackUid) return 1;
    if (uid == whiteUid) return 2;
    return 0;
  }

  /// [uid]が、相手が長期間応答していない対局の放置勝ちを申請できるか
  /// （PvpGameService.claimAbandonmentForfeit参照）。UIがボタンの表示判定
  /// に使い、サービス側のトランザクションでも同じ条件を再確認している。
  bool canClaimAbandonmentForfeit(String uid, {required Duration threshold}) {
    if (!isActive) return false;
    if (playerColorOf(uid) == 0) return false;
    if (isTurnOf(uid)) return false;
    final lastActivity = updatedAt ?? createdAt;
    return DateTime.now().difference(lastActivity) >= threshold;
  }

  bool isTurnOf(String uid) {
    final color = playerColorOf(uid);
    if (color == 0) return false;
    return (color == 1) == isBlackTurn;
  }

  factory PvpGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Firestoreは配列のネストを禁止しているため、各行を数字文字列
    // ("0120...")としてエンコードして保存している（SpectatorSessionと同様）。
    final boardSize = data['boardSize'] as int? ?? 19;
    final rawRows = data['stones'] as List<dynamic>?;
    final stones = rawRows != null
        ? rawRows.map((row) => (row as String).split('').map(int.parse).toList()).toList()
        : List.generate(boardSize, (_) => List.filled(boardSize, 0));

    return PvpGame(
      id: doc.id,
      boardSize: boardSize,
      blackUid: data['blackUid'] as String? ?? '',
      blackDisplayName: data['blackDisplayName'] as String? ?? 'Black',
      whiteUid: data['whiteUid'] as String? ?? '',
      whiteDisplayName: data['whiteDisplayName'] as String? ?? 'White',
      stones: stones,
      isBlackTurn: data['isBlackTurn'] as bool? ?? true,
      capturedBlack: data['capturedBlack'] as int? ?? 0,
      capturedWhite: data['capturedWhite'] as int? ?? 0,
      koRow: data['koRow'] as int?,
      koCol: data['koCol'] as int?,
      lastMoveRow: data['lastMoveRow'] as int?,
      lastMoveCol: data['lastMoveCol'] as int?,
      movesCount: data['movesCount'] as int? ?? 0,
      consecutivePasses: data['consecutivePasses'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      winnerUid: data['winnerUid'] as String?,
      result: data['result'] as String?,
      blackScore: (data['blackScore'] as num?)?.toDouble(),
      whiteScore: (data['whiteScore'] as num?)?.toDouble(),
      matchId: data['matchId'] as String?,
      tournamentId: data['tournamentId'] as String?,
      tournamentMatchId: data['tournamentMatchId'] as String?,
      spectatorSessionId: data['spectatorSessionId'] as String?,
      mainTimeSeconds: data['mainTimeSeconds'] as int? ?? 600,
      incrementSeconds: data['incrementSeconds'] as int? ?? 10,
      blackTimeMs: data['blackTimeMs'] as int?,
      whiteTimeMs: data['whiteTimeMs'] as int?,
      turnStartedAt: data['turnStartedAt'] != null
          ? (data['turnStartedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'boardSize': boardSize,
      'blackUid': blackUid,
      'blackDisplayName': blackDisplayName,
      'whiteUid': whiteUid,
      'whiteDisplayName': whiteDisplayName,
      'stones': stones.map((row) => row.join()).toList(),
      'isBlackTurn': isBlackTurn,
      'capturedBlack': capturedBlack,
      'capturedWhite': capturedWhite,
      'koRow': koRow,
      'koCol': koCol,
      'lastMoveRow': lastMoveRow,
      'lastMoveCol': lastMoveCol,
      'movesCount': movesCount,
      'consecutivePasses': consecutivePasses,
      'status': status,
      'winnerUid': winnerUid,
      'result': result,
      'blackScore': blackScore,
      'whiteScore': whiteScore,
      'matchId': matchId,
      'tournamentId': tournamentId,
      'tournamentMatchId': tournamentMatchId,
      'spectatorSessionId': spectatorSessionId,
      'mainTimeSeconds': mainTimeSeconds,
      'incrementSeconds': incrementSeconds,
      'blackTimeMs': blackTimeMs,
      'whiteTimeMs': whiteTimeMs,
      'turnStartedAt': turnStartedAt != null ? Timestamp.fromDate(turnStartedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}

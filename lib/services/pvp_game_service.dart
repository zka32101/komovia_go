import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart' show AbandonmentForfeitPolicy;
import 'package:logger/logger.dart';
import '../models/pvp_game.dart';
import 'go_rules.dart';
import 'go_scoring.dart';

final _logger = Logger();

/// PvP対局サービス - マッチング成立後の2人プレイヤー間リアルタイム対局
class PvpGameService {
  final FirebaseFirestore _firestore;

  PvpGameService(this._firestore);

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('pvp_games');

  /// マッチングエンジン経由の対局を作成する。トーナメント試合の対局は
  /// 排他制御が必要なため createGameForTournamentMatch を使うこと。
  Future<PvpGame> createGame({
    required int boardSize,
    required String blackUid,
    required String blackDisplayName,
    required String whiteUid,
    required String whiteDisplayName,
    String? matchId,
    int mainTimeSeconds = 600,
    int incrementSeconds = 10,
  }) async {
    try {
      final docRef = _games.doc();
      final game = PvpGame(
        id: docRef.id,
        boardSize: boardSize,
        blackUid: blackUid,
        blackDisplayName: blackDisplayName,
        whiteUid: whiteUid,
        whiteDisplayName: whiteDisplayName,
        stones: List.generate(boardSize, (_) => List.filled(boardSize, 0)),
        isBlackTurn: true,
        capturedBlack: 0,
        capturedWhite: 0,
        movesCount: 0,
        consecutivePasses: 0,
        status: 'active',
        matchId: matchId,
        mainTimeSeconds: mainTimeSeconds,
        incrementSeconds: incrementSeconds,
        turnStartedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await docRef.set(game.toFirestore());
      _logger.i('Created PvP game: ${docRef.id}');
      return game;
    } catch (e) {
      _logger.e('Error creating PvP game: $e');
      rethrow;
    }
  }

  /// トーナメント試合に対する対局を作成する。両対局者がほぼ同時に
  /// 「対局を開始する」を押しても対局が2つ作られないよう、
  /// 「試合にまだgameIdが無ければ作成する」をFirestoreトランザクションで
  /// アトミックに行う。既に対局が存在すれば新規作成せずそのgameIdを返す。
  Future<String> createGameForTournamentMatch({
    required String tournamentId,
    required String matchId,
    required int boardSize,
    required String blackUid,
    required String blackDisplayName,
    required String whiteUid,
    required String whiteDisplayName,
    int mainTimeSeconds = 600,
    int incrementSeconds = 10,
  }) async {
    try {
      return await _firestore.runTransaction<String>((transaction) async {
        final matchRef = _firestore
            .collection('tournaments')
            .doc(tournamentId)
            .collection('matches')
            .doc(matchId);
        final matchDoc = await transaction.get(matchRef);
        final existingGameId = matchDoc.data()?['gameId'] as String?;
        if (existingGameId != null) {
          _logger.i('Tournament match $matchId already has a game: $existingGameId');
          return existingGameId;
        }

        final gameRef = _games.doc();
        final game = PvpGame(
          id: gameRef.id,
          boardSize: boardSize,
          blackUid: blackUid,
          blackDisplayName: blackDisplayName,
          whiteUid: whiteUid,
          whiteDisplayName: whiteDisplayName,
          stones: List.generate(boardSize, (_) => List.filled(boardSize, 0)),
          isBlackTurn: true,
          capturedBlack: 0,
          capturedWhite: 0,
          movesCount: 0,
          consecutivePasses: 0,
          status: 'active',
          tournamentId: tournamentId,
          tournamentMatchId: matchId,
          mainTimeSeconds: mainTimeSeconds,
          incrementSeconds: incrementSeconds,
          turnStartedAt: DateTime.now(),
          createdAt: DateTime.now(),
        );
        transaction.set(gameRef, game.toFirestore());
        transaction.update(matchRef, {'gameId': gameRef.id, 'status': 'in_progress'});

        _logger.i('Created PvP game ${gameRef.id} for tournament match $matchId');
        return gameRef.id;
      });
    } catch (e) {
      _logger.e('Error creating game for tournament match: $e');
      rethrow;
    }
  }

  /// ライブ観戦フレンド機能用に、生成済みの観戦セッションIDを対局に紐付ける。
  /// Best-effort呼び出し専用（対局作成自体をブロックしないよう、失敗しても
  /// 対局は成立したままにする — 呼び出し元のcreatePvpGameProviderが処理する）。
  Future<void> attachSpectatorSession(String gameId, String sessionId) async {
    await _games.doc(gameId).update({'spectatorSessionId': sessionId});
  }

  /// トーナメント戦PvP対局向け: まだ観戦セッションが紐付いていない場合に
  /// のみ、事前に確保済みのsessionIdをトランザクションでアトミックに
  /// 紐付ける。両対局者がほぼ同時に対局を開始しても、片方だけが本当に
  /// 紐付けに成功する（もう一方はfalseを受け取り、その先の観戦セッション
  /// 作成・フレンド通知処理を丸ごとスキップする — sessionIdは未使用の
  /// まま捨てられ、Firestoreへの書き込みは一切発生していないので後片付け
  /// は不要）。attachSpectatorSessionの非トランザクション版（マッチング
  /// 経由の対局は常に新規作成された対局に対して1回しか呼ばれないため
  /// 競合の余地が無い）とは別に用意している。
  Future<bool> attachSpectatorSessionIfAbsent(String gameId, String sessionId) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final gameRef = _games.doc(gameId);
        final gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) return false;
        if (gameDoc.data()?['spectatorSessionId'] != null) return false;

        transaction.update(gameRef, {'spectatorSessionId': sessionId});
        return true;
      });
    } catch (e) {
      _logger.e('Error attaching spectator session if absent: $e');
      rethrow;
    }
  }

  Future<PvpGame?> getGame(String gameId) async {
    try {
      final doc = await _games.doc(gameId).get();
      if (!doc.exists) return null;
      return PvpGame.fromFirestore(doc);
    } catch (e) {
      _logger.e('Error getting PvP game: $e');
      rethrow;
    }
  }

  Stream<PvpGame?> streamGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (doc) => doc.exists ? PvpGame.fromFirestore(doc) : null,
        );
  }

  Future<List<PvpGame>> getUserActiveGames(String uid) async {
    try {
      final asBlack = await _games
          .where('blackUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      final asWhite = await _games
          .where('whiteUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      return [
        ...asBlack.docs.map(PvpGame.fromFirestore),
        ...asWhite.docs.map(PvpGame.fromFirestore),
      ];
    } catch (e) {
      _logger.e('Error getting user active PvP games: $e');
      rethrow;
    }
  }

  /// 手を打つ。トランザクションで読み取り・検証・書き込みを行い、
  /// 2人が同時に操作しても不整合が起きないようにする。
  /// 戻り値: 成功時true、非合法手やターン違反ならfalse。
  Future<bool> applyMove({
    required String gameId,
    required String uid,
    required int row,
    required int col,
  }) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          _logger.w('PvP game not found: $gameId');
          return false;
        }

        final game = PvpGame.fromFirestore(snapshot);
        if (!game.isActive) {
          _logger.w('PvP game already finished: $gameId');
          return false;
        }
        if (!game.isTurnOf(uid)) {
          _logger.w('Not $uid\'s turn in game $gameId');
          return false;
        }

        final now = DateTime.now();
        if (game.remainingMs(game.isBlackTurn, now) <= 0) {
          _logger.w('Move arrived after time expired: game=$gameId uid=$uid');
          return false;
        }

        final player = game.isBlackTurn ? 1 : 2;
        final result = GoRules.applyMove(
          stones: game.stones,
          boardSize: game.boardSize,
          row: row,
          col: col,
          player: player,
          koRow: game.koRow,
          koCol: game.koCol,
        );

        if (result == null) {
          _logger.w('Illegal PvP move rejected: game=$gameId [$row,$col]');
          return false;
        }

        final newBankMs =
            game.remainingMs(game.isBlackTurn, now) + game.incrementSeconds * 1000;

        transaction.update(docRef, {
          'stones': result.stones.map((r) => r.join()).toList(),
          'capturedBlack': player == 2 ? game.capturedBlack + result.capturedCount : game.capturedBlack,
          'capturedWhite': player == 1 ? game.capturedWhite + result.capturedCount : game.capturedWhite,
          'isBlackTurn': !game.isBlackTurn,
          'koRow': result.koRow,
          'koCol': result.koCol,
          'lastMoveRow': row,
          'lastMoveCol': col,
          'movesCount': game.movesCount + 1,
          'consecutivePasses': 0,
          if (game.isBlackTurn) 'blackTimeMs': newBankMs else 'whiteTimeMs': newBankMs,
          'turnStartedAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _logger.i('PvP move applied: game=$gameId player=$player [$row,$col]');
        return true;
      });
    } catch (e) {
      _logger.e('Error applying PvP move: $e');
      rethrow;
    }
  }

  /// パスする。2連続パスで'scoring'状態に移行し、死石マーキング
  /// （submitDeadStones参照）を経て終局する。AI対局はネイティブFuegoの
  /// 安全性読みで死石を自動検出できるが、PvP対局にはエンジンが介在しない
  /// ため、両プレイヤーの合意（相互マーキングの一致）で死石を確定する
  /// ——GoScoringの設計コメントが明示する「OGS/KGS/Tygemなど他の囲碁
  /// サーバーと同じ終局処理」そのもの。
  Future<bool> pass({required String gameId, required String uid}) async {
    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        final game = PvpGame.fromFirestore(snapshot);
        if (!game.isActive || !game.isTurnOf(uid)) return false;

        final now = DateTime.now();
        if (game.remainingMs(game.isBlackTurn, now) <= 0) {
          _logger.w('Pass arrived after time expired: game=$gameId uid=$uid');
          return false;
        }

        final consecutivePasses = game.consecutivePasses + 1;
        final gameEnded = consecutivePasses >= 2;
        final newBankMs =
            game.remainingMs(game.isBlackTurn, now) + game.incrementSeconds * 1000;

        final update = <String, dynamic>{
          'isBlackTurn': !game.isBlackTurn,
          'koRow': null,
          'koCol': null,
          'consecutivePasses': consecutivePasses,
          if (game.isBlackTurn) 'blackTimeMs': newBankMs else 'whiteTimeMs': newBankMs,
          'turnStartedAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (gameEnded) {
          update['status'] = 'scoring';
          update['blackDeadStones'] = null;
          update['whiteDeadStones'] = null;
        }

        transaction.update(docRef, update);
        _logger.i('PvP pass: game=$gameId uid=$uid ended=$gameEnded');
        return true;
      });
    } catch (e) {
      _logger.e('Error passing PvP game: $e');
      rethrow;
    }
  }

  /// 死石マーキングを提出する（status == 'scoring'の間のみ）。[deadPoints]は
  /// "row,col"の座標集合をエンコードした文字列に変換して保存する。
  ///
  /// 両者が提出済みで、集合が完全一致すれば合意成立として
  /// GoScoring.computeAreaScore（死石除去後）で確定・終局する。既に一方が
  /// 提出していて今回の提出が食い違う場合は不一致とみなし、両者の提出を
  /// クリアして'active'に戻し対局を再開する（2連続パスはこの時点で
  /// リセットするので、次のパスはまた新たに2回必要になる）。
  Future<void> submitDeadStones({
    required String gameId,
    required String uid,
    required Set<(int, int)> deadPoints,
  }) async {
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final game = PvpGame.fromFirestore(snapshot);
        if (!game.isScoring || game.playerColorOf(uid) == 0) return;

        final encoded = deadPoints.map((p) => '${p.$1},${p.$2}').toSet();
        final isBlack = game.playerColorOf(uid) == 1;
        final opponentEncoded = (isBlack ? game.whiteDeadStones : game.blackDeadStones)
            ?.toSet();

        if (opponentEncoded == null) {
          // 自分が最初の提出者。相手の提出を待つ。
          transaction.update(docRef, {
            if (isBlack) 'blackDeadStones': encoded.toList() else 'whiteDeadStones': encoded.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        if (!_setEquals(encoded, opponentEncoded)) {
          // 不一致。両者の提出をクリアし対局を再開する。
          transaction.update(docRef, {
            'status': 'active',
            'blackDeadStones': null,
            'whiteDeadStones': null,
            'consecutivePasses': 0,
            'turnStartedAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        // 合意成立。死石を除去して確定スコアリング。
        final deadPointsForScoring = encoded
            .map((s) {
              final parts = s.split(',');
              return (int.parse(parts[0]), int.parse(parts[1]));
            })
            .toSet();
        final scoredStones = GoScoring.withDeadStonesRemoved(game.stones, deadPointsForScoring);
        final areaScore = GoScoring.computeAreaScore(scoredStones, game.boardSize);

        transaction.update(docRef, {
          'status': 'finished',
          'winnerUid': areaScore.winnerUid(blackUid: game.blackUid, whiteUid: game.whiteUid),
          'result': 'score',
          'blackScore': areaScore.blackScore,
          'whiteScore': areaScore.whiteScore,
          if (isBlack) 'blackDeadStones': encoded.toList() else 'whiteDeadStones': encoded.toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      _logger.i('PvP dead stones submitted: game=$gameId uid=$uid');
    } catch (e) {
      _logger.e('Error submitting PvP dead stones: $e');
      rethrow;
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }

  /// トランザクション内で読み取り・判定・書き込みを行い、パス2連続による
  /// 終局処理（pass()）と同時に投了しても、後勝ちで結果が上書きされない
  /// ようにする（isActiveの再確認をコミット直前の状態に対して行う）。
  Future<void> resign({required String gameId, required String uid}) async {
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final game = PvpGame.fromFirestore(snapshot);
        if (!game.isActive) {
          _logger.w('PvP game already finished, ignoring resign: $gameId');
          return;
        }

        final color = game.playerColorOf(uid);
        if (color == 0) {
          _logger.w('Non-participant tried to resign PvP game: $gameId by=$uid');
          return;
        }
        final winnerUid = color == 1 ? game.whiteUid : game.blackUid;
        transaction.update(docRef, {
          'status': 'finished',
          'winnerUid': winnerUid,
          'result': 'resignation',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _logger.i('PvP game resigned: game=$gameId by=$uid');
      });
    } catch (e) {
      _logger.e('Error resigning PvP game: $e');
      rethrow;
    }
  }

  /// 相手が長期間応答していない（`updatedAt`からこの期間が経過している）
  /// 対局を、放置勝ちとして終局させる。「NO TIMERS」方針（対局中に時間
  /// 制限を課さない）とは別物 — 何日も現実に動きが無い対局を永久に
  /// 「進行中」で残さないための救済措置であり、1手ごとの時間制限ではない。
  /// komovia_coreの共有ポリシー（48時間 = [AbandonmentForfeitPolicy.slow]）。
  static const AbandonmentForfeitPolicy abandonmentPolicy =
      AbandonmentForfeitPolicy.slow;
  static final Duration abandonmentThreshold = abandonmentPolicy.threshold;

  /// トランザクション内で読み取り・判定・書き込みを行い、resign()/pass()
  /// と同時に呼ばれても後勝ちで結果が上書きされないようにする。
  Future<void> claimAbandonmentForfeit({
    required String gameId,
    required String claimantUid,
  }) async {
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final game = PvpGame.fromFirestore(snapshot);
        if (!game.isActive) {
          _logger.w('PvP game already finished, ignoring forfeit claim: $gameId');
          return;
        }

        final claimantColor = game.playerColorOf(claimantUid);
        if (claimantColor == 0) {
          _logger.w('Non-participant tried to claim forfeit: $gameId by=$claimantUid');
          return;
        }
        if (game.isTurnOf(claimantUid)) {
          // It's the claimant's own turn — they're the one who hasn't
          // moved, not the opponent, so they have nothing to claim.
          _logger.w('Claimant is the one whose turn it is, ignoring: $gameId by=$claimantUid');
          return;
        }

        if (!abandonmentPolicy.canClaim(
          isClaimantsTurn: false, // checked just above
          lastActivityAt: game.lastActivityAt,
        )) {
          _logger.w('Game not stale enough yet for forfeit claim: $gameId');
          return;
        }

        transaction.update(docRef, {
          'status': 'finished',
          'winnerUid': claimantUid,
          'result': 'forfeit',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _logger.i('PvP game forfeited by abandonment: game=$gameId winner=$claimantUid');
      });
    } catch (e) {
      _logger.e('Error claiming abandonment forfeit: $e');
      rethrow;
    }
  }

  /// 相手の持ち時間がライブで0になっていることを理由に、時間切れ勝ちを
  /// 申請する。claimAbandonmentForfeitと同じ「クライアント側から申告する」
  /// 設計（Firestoreにはサーバー側で動く時計が無いため）。トランザクション
  /// 内でゲームの現在状態に対して再度 canClaimTimeoutForfeit を確認する
  /// ことで、resign()/pass()/applyMove()と同時に呼ばれても後勝ちで結果が
  /// 上書きされないようにする。
  Future<void> claimTimeoutForfeit({
    required String gameId,
    required String claimantUid,
  }) async {
    try {
      await _firestore.runTransaction<void>((transaction) async {
        final docRef = _games.doc(gameId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final game = PvpGame.fromFirestore(snapshot);
        final now = DateTime.now();
        if (!game.canClaimTimeoutForfeit(claimantUid, now)) {
          _logger.w('Timeout forfeit claim rejected: game=$gameId by=$claimantUid');
          return;
        }

        transaction.update(docRef, {
          'status': 'finished',
          'winnerUid': claimantUid,
          'result': 'timeout',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _logger.i('PvP game forfeited by timeout: game=$gameId winner=$claimantUid');
      });
    } catch (e) {
      _logger.e('Error claiming timeout forfeit: $e');
      rethrow;
    }
  }
}

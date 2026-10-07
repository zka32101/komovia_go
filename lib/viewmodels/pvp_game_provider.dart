import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/leaderboard.dart';
import '../models/pvp_game.dart';
import '../services/pvp_game_service.dart';
import 'friend_activity_provider.dart';
import 'leaderboard_provider.dart';
import 'notification_provider.dart';
import 'spectator_provider.dart';
import 'tournament_provider.dart';

final _logger = Logger();

final pvpGameServiceProvider = Provider((ref) {
  return PvpGameService(FirebaseFirestore.instance);
});

/// 対局のリアルタイム盤面（両対局者・観戦者共通で購読）
final pvpGameStreamProvider =
    StreamProvider.family<PvpGame?, String>((ref, gameId) {
  final service = ref.watch(pvpGameServiceProvider);
  return service.streamGame(gameId);
});

/// ユーザーが参加中の対局一覧
final userActivePvpGamesProvider =
    FutureProvider.family<List<PvpGame>, String>((ref, uid) async {
  final service = ref.watch(pvpGameServiceProvider);
  try {
    final games = await service.getUserActiveGames(uid);
    _logger.i('Fetched ${games.length} active PvP games for $uid');
    return games;
  } catch (e) {
    _logger.e('Error fetching active PvP games: $e');
    rethrow;
  }
});

final createPvpGameProvider = Provider((ref) {
  return (
    int boardSize,
    String blackUid,
    String blackDisplayName,
    String whiteUid,
    String whiteDisplayName, {
    String? matchId,
  }) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      final game = await service.createGame(
        boardSize: boardSize,
        blackUid: blackUid,
        blackDisplayName: blackDisplayName,
        whiteUid: whiteUid,
        whiteDisplayName: whiteDisplayName,
        matchId: matchId,
      );
      _logger.i('Created PvP game: ${game.id}');
      _startPvpSpectatorSession(
        ref, service, game.id, boardSize, blackUid, blackDisplayName, whiteUid,
      );
      return game;
    } catch (e) {
      _logger.e('Error creating PvP game: $e');
      rethrow;
    }
  };
});

/// 縁機能: PvP対局もライブ観戦フレンドの対象にする（既存はAI対局のみ対応
/// だった）。Firestoreの spectator_sessions ルールは
/// `hostUid == request.auth.uid` を作成条件にしているため、hostUidには
/// このコードを実行している呼び出し元自身のuidを使う必要がある —
/// 現状の唯一の呼び出し元（matching_screen.dart）は常に自分自身を黒番
/// として渡すため、blackUidをhostUidに使えば一致する。Best-effort:
/// fire-and-forget（呼び出し元のawaitをブロックしない）。
void _startPvpSpectatorSession(
  Ref ref,
  PvpGameService service,
  String gameId,
  int boardSize,
  String hostUid,
  String hostDisplayName,
  String coHostUid,
) {
  () async {
    try {
      final session = await ref.read(createSpectatorSessionProvider)(
        gameId,
        'pvp_game',
        hostUid,
        hostDisplayName,
        true,
        boardSize: boardSize,
        coHostUid: coHostUid,
      );
      await service.attachSpectatorSession(gameId, session.id);

      try {
        await ref.read(notifyFriendsOfLiveSessionProvider)(
          hostUid,
          hostDisplayName,
          session.id,
          'pvp_game',
        );
      } catch (e) {
        _logger.w('縁: PvP friend live-session notification failed (non-fatal): $e');
      }
    } catch (e) {
      _logger.w('縁: PvP spectator session creation failed (non-fatal): $e');
    }
  }();
}

/// トーナメント試合用の対局作成。両対局者がほぼ同時に開始しても
/// 対局が2つ作られないよう、Firestoreトランザクションで排他制御される
/// （PvpGameService.createGameForTournamentMatch参照）。
final createTournamentGameProvider = Provider((ref) {
  return (
    String tournamentId,
    String matchId,
    int boardSize,
    String blackUid,
    String blackDisplayName,
    String whiteUid,
    String whiteDisplayName,
    String callerUid,
  ) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      final gameId = await service.createGameForTournamentMatch(
        tournamentId: tournamentId,
        matchId: matchId,
        boardSize: boardSize,
        blackUid: blackUid,
        blackDisplayName: blackDisplayName,
        whiteUid: whiteUid,
        whiteDisplayName: whiteDisplayName,
      );
      _logger.i('Tournament game ready: $gameId');
      _startTournamentSpectatorSessionIfNeeded(
        ref,
        service,
        gameId,
        boardSize,
        blackUid,
        blackDisplayName,
        whiteUid,
        whiteDisplayName,
        callerUid,
      );
      return gameId;
    } catch (e) {
      _logger.e('Error creating tournament game: $e');
      rethrow;
    }
  };
});

/// 縁機能: トーナメント戦のPvP対局もライブ観戦フレンドの対象にする。
/// createGameForTournamentMatchは「まだ無ければ作成」をトランザクションで
/// 保証するため対局自体は1つしか作られないが、両対局者がほぼ同時に
/// 「対局を開始する」を押すと、このメソッド自体は両方の呼び出しで走る
/// ため、観戦セッションの紐付けだけは別途アトミックにする必要がある —
/// セッションIDを先に確保し、attachSpectatorSessionIfAbsentのトランザク
/// ションで「まだ紐付いていなければ紐付ける」を行い、実際に紐付けに
/// 成功した呼び出しだけがセッションドキュメントを作成・フレンド通知する
/// （負けた側はFirestoreへの書き込みを一切行わずに抜ける）。hostUidは
/// Firestoreルール上request.auth.uidと一致させる必要があるため、常に
/// 「このコードを実行している呼び出し元自身」のuid（callerUid）を使う —
/// トーナメント戦では黒番が必ずしも呼び出し元自身とは限らない（UIDの
/// 辞書順で固定されるため、対局を開始する操作をしたのがどちらの
/// プレイヤーでも黒番になり得る）。
void _startTournamentSpectatorSessionIfNeeded(
  Ref ref,
  PvpGameService service,
  String gameId,
  int boardSize,
  String blackUid,
  String blackDisplayName,
  String whiteUid,
  String whiteDisplayName,
  String callerUid,
) {
  () async {
    try {
      final sessionId = ref.read(spectatorServiceProvider).reserveSessionId();
      final attached = await service.attachSpectatorSessionIfAbsent(gameId, sessionId);
      if (!attached) return; // 対局には既に他方の呼び出しが紐付け済み

      final callerIsBlack = callerUid == blackUid;
      final hostDisplayName = callerIsBlack ? blackDisplayName : whiteDisplayName;
      final coHostUid = callerIsBlack ? whiteUid : blackUid;

      await ref.read(createSpectatorSessionProvider)(
        gameId,
        'pvp_game',
        callerUid,
        hostDisplayName,
        true,
        boardSize: boardSize,
        coHostUid: coHostUid,
        id: sessionId,
      );

      try {
        await ref.read(notifyFriendsOfLiveSessionProvider)(
          callerUid, hostDisplayName, sessionId, 'pvp_game',
        );
      } catch (e) {
        _logger.w('縁: tournament PvP friend live-session notification failed (non-fatal): $e');
      }
    } catch (e) {
      _logger.w('縁: tournament PvP spectator session check failed (non-fatal): $e');
    }
  }();
}

final applyPvpMoveProvider = Provider((ref) {
  return (String gameId, String uid, int row, int col) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      final applied = await service.applyMove(gameId: gameId, uid: uid, row: row, col: col);
      if (applied) {
        _syncPvpSpectatorBoard(ref, service, gameId, row, col);
      }
      return applied;
    } catch (e) {
      _logger.e('Error applying PvP move: $e');
      rethrow;
    }
  };
});

/// 縁機能: 開いている観戦セッションがあれば毎手盤面を同期する
/// （ai_game版のgame_provider.dart _syncSpectatorBoardと同じ考え方）。
/// applyMoveはbool しか返さないため、同期に必要な最新盤面を得るために
/// 対局を読み直す — best-effort、対局のUI応答をブロックしないよう
/// fire-and-forgetにする。
void _syncPvpSpectatorBoard(
  Ref ref,
  PvpGameService service,
  String gameId,
  int lastMoveRow,
  int lastMoveCol,
) {
  () async {
    try {
      final game = await service.getGame(gameId);
      final sessionId = game?.spectatorSessionId;
      if (game == null || sessionId == null) return;

      await ref.read(updateSpectatorBoardStateProvider)(
        sessionId,
        game.movesCount,
        game.stones,
        game.isBlackTurn,
        lastMoveRow,
        lastMoveCol,
      );
    } catch (e) {
      _logger.w('縁: PvP spectator board sync failed (non-fatal): $e');
    }
  }();
}

final passPvpGameProvider = Provider((ref) {
  return (String gameId, String uid) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      // pass()'s return value is whether the pass itself was accepted
      // (legal turn), not whether it ended the game — the game-over check
      // happens inside _onGameFinished via game.isFinished.
      final accepted = await service.pass(gameId: gameId, uid: uid);
      if (accepted) {
        await _onGameFinished(ref, service, gameId);
      }
      return accepted;
    } catch (e) {
      _logger.e('Error passing PvP game: $e');
      rethrow;
    }
  };
});

final resignPvpGameProvider = Provider((ref) {
  return (String gameId, String uid) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      await service.resign(gameId: gameId, uid: uid);
      _logger.i('Resigned PvP game: $gameId');
      await _onGameFinished(ref, service, gameId);
    } catch (e) {
      _logger.e('Error resigning PvP game: $e');
      rethrow;
    }
  };
});

/// 同じ相手ともう一局。前回の対局から色を入れ替えて（白番だった方が今度は
/// 黒番）createPvpGameProviderで新規対局を作成する — 通常のマッチング経由
/// の対局と同じ経路を通すことで、観戦セッション作成等の副作用も同様に
/// 発生する。相手には対局成立時と同じpvp_challenge通知で知らせる
/// （matching_screen.dart._startGameと同じ役割）。通知文言は他の
/// best-effort通知（friend_activity_service.dart等）と同様、
/// ロケール非対応のハードコード文言。
final rematchPvpGameProvider = Provider((ref) {
  return (PvpGame previousGame, String requestingUid) async {
    try {
      final newGame = await ref.read(createPvpGameProvider)(
        previousGame.boardSize,
        previousGame.whiteUid,
        previousGame.whiteDisplayName,
        previousGame.blackUid,
        previousGame.blackDisplayName,
      );

      final opponentUid = requestingUid == previousGame.blackUid
          ? previousGame.whiteUid
          : previousGame.blackUid;
      final requesterDisplayName = requestingUid == previousGame.blackUid
          ? previousGame.blackDisplayName
          : previousGame.whiteDisplayName;

      try {
        await ref.read(sendNotificationProvider)(
          uid: opponentUid,
          title: '$requesterDisplayNameさんが再戦を希望しています',
          body: 'タップして対局を始めましょう',
          type: 'pvp_challenge',
          data: {'gameId': newGame.id},
        );
      } catch (e) {
        _logger.w('Failed to notify opponent of rematch (non-fatal): $e');
      }

      _logger.i('Rematch created: ${newGame.id} (from ${previousGame.id})');
      return newGame;
    } catch (e) {
      _logger.e('Error creating rematch: $e');
      rethrow;
    }
  };
});

/// 相手が長期間応答していない対局を放置勝ちとして終局させる
/// （PvpGameService.claimAbandonmentForfeit参照）。resignと同じく
/// Eloレーティング・トーナメント結果報告を_onGameFinishedで反映する。
final claimAbandonmentForfeitProvider = Provider((ref) {
  return (String gameId, String claimantUid) async {
    final service = ref.watch(pvpGameServiceProvider);
    try {
      await service.claimAbandonmentForfeit(gameId: gameId, claimantUid: claimantUid);
      _logger.i('Claimed abandonment forfeit: $gameId by=$claimantUid');
      await _onGameFinished(ref, service, gameId);
    } catch (e) {
      _logger.e('Error claiming abandonment forfeit: $e');
      rethrow;
    }
  };
});

/// 対局が終局していれば、Eloレーティングの反映とトーナメント結果報告
/// （紐づいていれば）を行う。それぞれ独立してbest-effortで処理し、
/// 片方の失敗が他方をブロックしたり対局そのものの完了を妨げたりしない。
Future<void> _onGameFinished(
  Ref ref,
  PvpGameService service,
  String gameId,
) async {
  PvpGame? game;
  try {
    game = await service.getGame(gameId);
  } catch (e) {
    _logger.w('Failed to fetch finished game (non-fatal): $e');
    return;
  }
  if (game == null || !game.isFinished) return;

  try {
    await _updateEloRatings(ref, game);
  } catch (e) {
    _logger.w('Failed to update Elo ratings (non-fatal): $e');
  }

  if (game.spectatorSessionId != null) {
    try {
      await ref.read(endSpectatorSessionProvider)(game.spectatorSessionId!);
    } catch (e) {
      _logger.w('縁: PvP spectator session end failed (non-fatal): $e');
    }
  }

  if (game.tournamentId == null || game.tournamentMatchId == null || game.winnerUid == null) {
    return; // 未紐付け、または引き分けならトーナメント結果は反映しない
  }
  try {
    final tournamentService = ref.read(tournamentServiceProvider);
    await tournamentService.recordMatchResult(
      tournamentId: game.tournamentId!,
      matchId: game.tournamentMatchId!,
      winnerUid: game.winnerUid!,
    );
    _logger.i('Reported tournament result for match ${game.tournamentMatchId}');
  } catch (e) {
    _logger.w('Failed to report tournament result (non-fatal): $e');
  }
}

/// 終局したPvP対局の結果を標準的なElo式でレーティングに反映する
/// （K=32固定）。leaderboards/all_time/rating/{uid} を読み書きする —
/// daily/weekly/monthly はリセット機構（Cloud Functions相当）がまだ
/// 無いため対象外（更新するとリセットされないまま累積するだけになる）。
Future<void> _updateEloRatings(Ref ref, PvpGame game) async {
  const kFactor = 32;
  final leaderboardService = ref.read(leaderboardServiceProvider);
  final incrementStats = ref.read(incrementUserStatsProvider);

  final blackEntry = await leaderboardService.getUserRank(
    uid: game.blackUid,
    period: LeaderboardPeriod.allTime,
    type: LeaderboardType.rating,
  );
  final whiteEntry = await leaderboardService.getUserRank(
    uid: game.whiteUid,
    period: LeaderboardPeriod.allTime,
    type: LeaderboardType.rating,
  );
  final blackRating = blackEntry?.rating ?? 1200;
  final whiteRating = whiteEntry?.rating ?? 1200;

  final double blackScore;
  if (game.winnerUid == game.blackUid) {
    blackScore = 1.0;
  } else if (game.winnerUid == game.whiteUid) {
    blackScore = 0.0;
  } else {
    blackScore = 0.5; // 引き分け
  }
  final whiteScore = 1.0 - blackScore;

  final expectedBlack = 1.0 / (1.0 + pow(10, (whiteRating - blackRating) / 400));
  final expectedWhite = 1.0 - expectedBlack;

  final newBlackRating = (blackRating + kFactor * (blackScore - expectedBlack)).round();
  final newWhiteRating = (whiteRating + kFactor * (whiteScore - expectedWhite)).round();

  await incrementStats(
    uid: game.blackUid,
    displayName: game.blackDisplayName,
    period: LeaderboardPeriod.allTime,
    type: LeaderboardType.rating,
    newRating: newBlackRating,
    gamesPlayedDelta: 1,
    winsDelta: blackScore == 1.0 ? 1 : 0,
  );
  await incrementStats(
    uid: game.whiteUid,
    displayName: game.whiteDisplayName,
    period: LeaderboardPeriod.allTime,
    type: LeaderboardType.rating,
    newRating: newWhiteRating,
    gamesPlayedDelta: 1,
    winsDelta: whiteScore == 1.0 ? 1 : 0,
  );
  _logger.i(
    'Elo updated: black ${game.blackUid} $blackRating->$newBlackRating, '
    'white ${game.whiteUid} $whiteRating->$newWhiteRating',
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/models/index.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Team ゲームサービス - 2vs2 協力戦
class TeamGameService {
  final FirebaseFirestore _firestore;

  TeamGameService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Team ゲームを開始
  /// [team1Players] - チーム1 のプレイヤー ID リスト（2名）
  /// [team2Players] - チーム2 のプレイヤー ID リスト（2名）
  Future<TeamGameRecord> startTeamGame({
    required List<String> team1Players,
    required List<String> team2Players,
    required int boardSize,
  }) async {
    try {
      _logger.i(
        'Starting Team game - '
        'team1: $team1Players, team2: $team2Players, boardSize: $boardSize',
      );

      if (team1Players.length != 2 || team2Players.length != 2) {
        throw Exception('Each team must have exactly 2 players');
      }

      final now = DateTime.now();
      final gameId = _firestore.collection('teamGames').doc().id;

      final game = TeamGameRecord(
        id: gameId,
        team1Players: team1Players,
        team2Players: team2Players,
        boardSize: boardSize,
        startedAt: now,
        endedAt: now,
        durationSeconds: 0,
        result: 'draw',
        winningTeam: 'draw',
        moveHistory: [],
        sgfData: '',
        team1Moves: '',
        team2Moves: '',
        createdAt: now,
      );

      await _firestore.collection('teamGames').doc(gameId).set(game.toJson());

      // すべてのプレイヤーに通知を送信
      final allPlayers = [...team1Players, ...team2Players];
      for (final playerId in allPlayers) {
        await _sendTeamGameNotification(
          recipientUid: playerId,
          gameId: gameId,
          message: 'Team ゲームが開始しました',
        );
      }

      _logger.i('Team game created: $gameId');
      return game;
    } catch (e) {
      _logger.e('Error starting Team game: $e');
      rethrow;
    }
  }

  /// Team ゲームに手を追加
  /// [playerColor] - プレイヤーの色 ('white' = team1, 'black' = team2)
  Future<void> addMoveToTeamGame({
    required String gameId,
    required String move,
    required String playerColor,
  }) async {
    try {
      _logger.i('Adding move to Team game: $gameId, color: $playerColor');

      final gameDoc = await _firestore.collection('teamGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = TeamGameRecord.fromJson(gameDoc.data()!);

      // チーム別の手を更新
      if (playerColor == 'white') {
        await _firestore.collection('teamGames').doc(gameId).update({
          'moveHistory': FieldValue.arrayUnion([move]),
          'team1Moves': '${game.team1Moves}$move ',
        });
      } else if (playerColor == 'black') {
        await _firestore.collection('teamGames').doc(gameId).update({
          'moveHistory': FieldValue.arrayUnion([move]),
          'team2Moves': '${game.team2Moves}$move ',
        });
      } else {
        throw Exception('Invalid player color: $playerColor');
      }

      _logger.i('Move added to Team game');
    } catch (e) {
      _logger.e('Error adding move: $e');
      rethrow;
    }
  }

  /// Team ゲームを終了
  Future<TeamGameRecord> endTeamGame({
    required String gameId,
    required String result, // 'team1_win', 'team2_win', 'draw'
    required String sgfData,
  }) async {
    try {
      _logger.i('Ending Team game: $gameId, result: $result');

      final gameDoc = await _firestore.collection('teamGames').doc(gameId).get();

      if (!gameDoc.exists) {
        throw Exception('Game not found: $gameId');
      }

      final game = TeamGameRecord.fromJson(gameDoc.data()!);
      final now = DateTime.now();
      final duration = now.difference(game.startedAt).inSeconds;

      final winningTeam = result == 'team1_win'
          ? 'team1'
          : result == 'team2_win'
              ? 'team2'
              : 'draw';

      final updatedGame = game.copyWith(
        endedAt: now,
        durationSeconds: duration,
        result: result,
        winningTeam: winningTeam,
        sgfData: sgfData,
      );

      await _firestore
          .collection('teamGames')
          .doc(gameId)
          .set(updatedGame.toJson());

      // すべてのプレイヤーに結果を通知
      final allPlayers = [...game.team1Players, ...game.team2Players];
      for (final playerId in allPlayers) {
        await _sendTeamGameNotification(
          recipientUid: playerId,
          gameId: gameId,
          message: 'Team ゲームが終了しました。結果: $result',
        );
      }

      _logger.i('Team game ended');
      return updatedGame;
    } catch (e) {
      _logger.e('Error ending Team game: $e');
      rethrow;
    }
  }

  /// プレイヤーが参加している Team ゲーム一覧を取得
  Future<List<TeamGameRecord>> getPlayerTeamGames({
    required String uid,
    int limit = 20,
  }) async {
    try {
      _logger.i('Fetching Team games for player: $uid');

      // プレイヤーが所属するチームのゲームを検索
      final team1Query = _firestore
          .collection('teamGames')
          .where('team1Players', arrayContains: uid)
          .orderBy('startedAt', descending: true)
          .limit(limit);

      final team2Query = _firestore
          .collection('teamGames')
          .where('team2Players', arrayContains: uid)
          .orderBy('startedAt', descending: true)
          .limit(limit);

      final team1Snapshot = await team1Query.get();
      final team2Snapshot = await team2Query.get();

      final allGames = [
        ...team1Snapshot.docs.map((doc) => TeamGameRecord.fromJson(doc.data())),
        ...team2Snapshot.docs.map((doc) => TeamGameRecord.fromJson(doc.data())),
      ];

      // 時系列でソート
      allGames.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      _logger.i('Fetched ${allGames.length} Team games');
      return allGames.take(limit).toList();
    } catch (e) {
      _logger.e('Error fetching Team games: $e');
      rethrow;
    }
  }

  /// Team ゲーム統計情報を取得
  Future<TeamGameStats> getTeamGameStats({required String uid}) async {
    try {
      _logger.i('Fetching Team game stats for player: $uid');

      final games = await getPlayerTeamGames(uid: uid, limit: 100);

      int team1Wins = 0;
      int team2Wins = 0;
      int draws = 0;
      int totalGames = games.length;

      for (final game in games) {
        final isInTeam1 = game.team1Players.contains(uid);

        if (game.result == 'draw') {
          draws++;
        } else if (game.result == 'team1_win' && isInTeam1) {
          team1Wins++;
        } else if (game.result == 'team2_win' && !isInTeam1) {
          team2Wins++;
        }
      }

      final totalWins = team1Wins + team2Wins;
      final winRate = totalGames > 0
          ? ((totalWins / totalGames) * 100).toStringAsFixed(1)
          : '0.0';

      final stats = TeamGameStats(
        totalGames: totalGames,
        wins: totalWins,
        losses: totalGames - totalWins - draws,
        draws: draws,
        winRate: winRate,
        mostFrequentPartners:
            await _getMostFrequentPartners(gameList: games, uid: uid),
      );

      _logger.i('Team game stats: $stats');
      return stats;
    } catch (e) {
      _logger.e('Error fetching Team game stats: $e');
      rethrow;
    }
  }

  /// 最頻繁なパートナーを取得
  Future<List<String>> _getMostFrequentPartners({
    required List<TeamGameRecord> gameList,
    required String uid,
  }) async {
    final partnerCount = <String, int>{};

    for (final game in gameList) {
      final isInTeam1 = game.team1Players.contains(uid);
      final partners =
          isInTeam1 ? game.team1Players : game.team2Players;

      for (final partner in partners) {
        if (partner != uid) {
          partnerCount[partner] = (partnerCount[partner] ?? 0) + 1;
        }
      }
    }

    // 頻度でソート
    final sorted = partnerCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) => e.key).toList();
  }

  /// Team ゲーム通知を送信
  ///
  /// Writes to `notifications/{uid}/messages/{id}` (the shape
  /// NotificationService/notification_provider.dart actually read for the
  /// notification bell) rather than a flat `notifications/{autoId}` doc
  /// with a `recipientUid` field — that shape was never read by anything,
  /// so these notifications silently never reached the UI.
  Future<void> _sendTeamGameNotification({
    required String recipientUid,
    required String gameId,
    required String message,
  }) async {
    try {
      final docRef = _firestore
          .collection('notifications')
          .doc(recipientUid)
          .collection('messages')
          .doc();

      final notification = AppNotification(
        id: docRef.id,
        uid: recipientUid,
        title: 'チーム対局',
        body: message,
        data: {'gameId': gameId, 'gameType': 'team'},
        type: 'team_game',
        isRead: false,
        createdAt: DateTime.now(),
      );

      await docRef.set(notification.toFirestore());

      _logger.i('Team game notification sent: ${docRef.id}');
    } catch (e) {
      _logger.e('Error sending Team game notification: $e');
    }
  }
}

/// Team ゲーム統計情報
class TeamGameStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final String winRate;
  final List<String> mostFrequentPartners;

  TeamGameStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.mostFrequentPartners,
  });

  @override
  String toString() => 'TeamGameStats('
      'totalGames: $totalGames, '
      'wins: $wins, '
      'losses: $losses, '
      'draws: $draws, '
      'winRate: $winRate%, '
      'mostFrequentPartners: $mostFrequentPartners)';
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// トーナメント
class Tournament {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  final String format; // 'single_elimination', 'round_robin', 'swiss'
  final String status; // 'upcoming', 'active', 'completed', 'cancelled'
  final List<String> participantUids;
  final String? winnerId;
  // 主催者のuid。startTournament等の主催者限定操作をrulesで判定するために
  // 作成時に一度だけ設定し、以後は不変として扱う。functions/の週刊自動開催
  // ジョブが作った大会はnull（Admin SDK書き込みのためrulesの対象外）。
  final String? createdBy;
  final int boardSize; // 対局に使う碁盤サイズ（9/13/19）
  // 次ラウンド生成済みの最大ラウンド番号（0=未生成）。
  // _advanceRoundIfCompleteの二重生成防止に使う内部管理フィールド。
  final int lastAdvancedRound;
  // functions/src/weeklyTournament.tsの週刊自動開催ジョブが作った大会か。
  // trueの大会は毎週月曜(JST)に前週分の自動開始/新規作成が行われる。
  final bool isAutoWeekly;
  // swiss形式のみ使用（開始時に参加者数から自動計算して固定）。何回戦で
  // 打ち切って順位表から優勝を確定するか。single_elimination/round_robin
  // は0のまま（不要 — 前者は勝者1人になるまで、後者は全カード終了まで）。
  final int totalRounds;
  final DateTime createdAt;

  Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.maxParticipants,
    required this.format,
    required this.status,
    required this.participantUids,
    this.winnerId,
    this.createdBy,
    this.boardSize = 19,
    this.lastAdvancedRound = 0,
    this.isAutoWeekly = false,
    this.totalRounds = 0,
    required this.createdAt,
  });

  factory Tournament.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Tournament(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      startDate: data['startDate'] is Timestamp
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] is Timestamp
          ? (data['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      maxParticipants: data['maxParticipants'] ?? 0,
      format: data['format'] ?? 'single_elimination',
      status: data['status'] ?? 'upcoming',
      participantUids: List<String>.from(data['participantUids'] ?? []),
      winnerId: data['winnerId'],
      createdBy: data['createdBy'],
      boardSize: data['boardSize'] as int? ?? 19,
      lastAdvancedRound: data['lastAdvancedRound'] as int? ?? 0,
      isAutoWeekly: data['isAutoWeekly'] as bool? ?? false,
      totalRounds: data['totalRounds'] as int? ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'maxParticipants': maxParticipants,
      'format': format,
      'status': status,
      'participantUids': participantUids,
      'winnerId': winnerId,
      'createdBy': createdBy,
      'boardSize': boardSize,
      'lastAdvancedRound': lastAdvancedRound,
      'isAutoWeekly': isAutoWeekly,
      'totalRounds': totalRounds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isFull => participantUids.length >= maxParticipants;
  bool get isUpcoming => status == 'upcoming';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  // 週刊自動開催で参加者が2人未満のまま開始時刻を迎えた大会に付く状態。
  bool get isCancelled => status == 'cancelled';

  @override
  String toString() => 'Tournament(id: $id, name: $name)';
}

/// トーナメント参加者
class TournamentParticipant {
  final String tournamentId;
  final String uid;
  final String displayName;
  final int? seed;
  final int? currentRound;
  final int? currentRanking;
  final DateTime joinedAt;

  TournamentParticipant({
    required this.tournamentId,
    required this.uid,
    required this.displayName,
    this.seed,
    this.currentRound,
    this.currentRanking,
    required this.joinedAt,
  });

  factory TournamentParticipant.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TournamentParticipant(
      tournamentId: data['tournamentId'] ?? '',
      uid: doc.id,
      displayName: data['displayName'] ?? 'Player',
      seed: data['seed'],
      currentRound: data['currentRound'],
      currentRanking: data['currentRanking'],
      joinedAt: data['joinedAt'] is Timestamp
          ? (data['joinedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'displayName': displayName,
      'seed': seed,
      'currentRound': currentRound,
      'currentRanking': currentRanking,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  @override
  String toString() =>
      'TournamentParticipant(tournament: $tournamentId, uid: $uid)';
}

/// トーナメント試合
class TournamentMatch {
  final String id;
  final String tournamentId;
  final String? player1Uid;
  final String? player1DisplayName;
  final String? player2Uid;
  final String? player2DisplayName;
  final int round;
  final String? winnerUid;
  final String status; // 'pending', 'in_progress', 'completed'
  final String? gameId; // 紐付けられたPvpGameのID（試合開始後に設定）
  final DateTime scheduledAt;
  final DateTime? completedAt;

  TournamentMatch({
    required this.id,
    required this.tournamentId,
    this.player1Uid,
    this.player1DisplayName,
    this.player2Uid,
    this.player2DisplayName,
    required this.round,
    this.winnerUid,
    required this.status,
    this.gameId,
    required this.scheduledAt,
    this.completedAt,
  });

  /// 相手が不在（不戦勝）の枠
  bool get isBye => player1Uid == null || player2Uid == null;

  factory TournamentMatch.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TournamentMatch(
      id: doc.id,
      tournamentId: data['tournamentId'] ?? '',
      player1Uid: data['player1Uid'],
      player1DisplayName: data['player1DisplayName'],
      player2Uid: data['player2Uid'],
      player2DisplayName: data['player2DisplayName'],
      round: data['round'] ?? 1,
      winnerUid: data['winnerUid'],
      status: data['status'] ?? 'pending',
      gameId: data['gameId'],
      scheduledAt: data['scheduledAt'] is Timestamp
          ? (data['scheduledAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tournamentId': tournamentId,
      'player1Uid': player1Uid,
      'player1DisplayName': player1DisplayName,
      'player2Uid': player2Uid,
      'player2DisplayName': player2DisplayName,
      'round': round,
      'winnerUid': winnerUid,
      'status': status,
      'gameId': gameId,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  @override
  String toString() =>
      'TournamentMatch(id: $id, round: $round, status: $status)';
}

/// 総当たり戦（round_robin）の順位表1行分。TournamentService.getStandings
/// が完了済み試合から都度計算する（Firestoreには保存されない）。
class TournamentStandingEntry {
  final String uid;
  final String displayName;
  final int wins;
  final int losses;

  TournamentStandingEntry({
    required this.uid,
    required this.displayName,
    required this.wins,
    required this.losses,
  });

  int get played => wins + losses;
}

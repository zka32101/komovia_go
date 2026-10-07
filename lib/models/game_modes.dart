import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_modes.freezed.dart';
part 'game_modes.g.dart';

/// Blitz ゲーム記録 - 5分急速戦
@freezed
abstract class BlitzGameRecord with _$BlitzGameRecord {
  const factory BlitzGameRecord({
    required String id,
    required String uid,
    required int boardSize,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required String? aiLevel, // null なら対人戦
    required String opponentUid, // AI の場合は 'ai'
    required String whitePlayer,
    required String blackPlayer,
    required String result, // 'win', 'loss', 'draw'
    required String winnerColor, // 'white', 'black', 'draw'
    required List<String> moveHistory,
    required String sgfData,
    required int ratingChange,
    required DateTime createdAt,
  }) = _BlitzGameRecord;

  factory BlitzGameRecord.fromJson(Map<String, dynamic> json) =>
      _$BlitzGameRecordFromJson(json);

  factory BlitzGameRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BlitzGameRecord.fromJson({
      ...data,
      'id': doc.id,
      'startedAt': (data['startedAt'] as Timestamp).toDate(),
      'endedAt': (data['endedAt'] as Timestamp).toDate(),
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
    });
  }

  factory BlitzGameRecord.empty() => BlitzGameRecord(
    id: '',
    uid: '',
    boardSize: 19,
    startedAt: DateTime.now(),
    endedAt: DateTime.now(),
    durationSeconds: 0,
    aiLevel: null,
    opponentUid: 'ai',
    whitePlayer: '',
    blackPlayer: '',
    result: 'draw',
    winnerColor: 'draw',
    moveHistory: [],
    sgfData: '',
    ratingChange: 0,
    createdAt: DateTime.now(),
  );
}

/// Correspondence ゲーム記録 - 手紙型ターン制対局
@freezed
abstract class CorrespondenceGameRecord with _$CorrespondenceGameRecord {
  const factory CorrespondenceGameRecord({
    required String id,
    required String uid,
    required String opponentUid,
    required int boardSize,
    required DateTime startDate,
    required DateTime? endDate,
    required int currentTurnNumber,
    required String currentPlayerColor, // 'white', 'black'
    required String status, // 'active', 'completed', 'abandoned'
    required List<String> moveHistory,
    required DateTime lastMoveAt,
    required String result, // 'win', 'loss', 'draw', 'abandoned'
    required String? winnerColor,
    required String sgfData,
    required int timePerMoveHours,
    required DateTime createdAt,
  }) = _CorrespondenceGameRecord;

  factory CorrespondenceGameRecord.fromJson(Map<String, dynamic> json) =>
      _$CorrespondenceGameRecordFromJson(json);

  factory CorrespondenceGameRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CorrespondenceGameRecord.fromJson({
      ...data,
      'id': doc.id,
      'startDate': (data['startDate'] as Timestamp).toDate(),
      'endDate': data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      'lastMoveAt': (data['lastMoveAt'] as Timestamp).toDate(),
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
    });
  }

  factory CorrespondenceGameRecord.empty() => CorrespondenceGameRecord(
    id: '',
    uid: '',
    opponentUid: '',
    boardSize: 19,
    startDate: DateTime.now(),
    endDate: null,
    currentTurnNumber: 0,
    currentPlayerColor: 'black',
    status: 'active',
    moveHistory: [],
    lastMoveAt: DateTime.now(),
    result: 'abandoned',
    winnerColor: null,
    sgfData: '',
    timePerMoveHours: 24,
    createdAt: DateTime.now(),
  );
}

/// Team ゲーム記録 - 2vs2 協力戦
@freezed
abstract class TeamGameRecord with _$TeamGameRecord {
  const factory TeamGameRecord({
    required String id,
    required List<String> team1Players, // [player1, player2]
    required List<String> team2Players, // [player3, player4]
    required int boardSize,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required String result, // 'team1_win', 'team2_win', 'draw'
    required String winningTeam, // 'team1', 'team2', 'draw'
    required List<String> moveHistory,
    required String sgfData,
    required String team1Moves, // white の手
    required String team2Moves, // black の手
    required DateTime createdAt,
  }) = _TeamGameRecord;

  factory TeamGameRecord.fromJson(Map<String, dynamic> json) =>
      _$TeamGameRecordFromJson(json);

  factory TeamGameRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamGameRecord.fromJson({
      ...data,
      'id': doc.id,
      'startedAt': (data['startedAt'] as Timestamp).toDate(),
      'endedAt': (data['endedAt'] as Timestamp).toDate(),
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
    });
  }

  factory TeamGameRecord.empty() => TeamGameRecord(
    id: '',
    team1Players: [],
    team2Players: [],
    boardSize: 19,
    startedAt: DateTime.now(),
    endedAt: DateTime.now(),
    durationSeconds: 0,
    result: 'draw',
    winningTeam: 'draw',
    moveHistory: [],
    sgfData: '',
    team1Moves: '',
    team2Moves: '',
    createdAt: DateTime.now(),
  );
}

/// Puzzle Rush レコード - タイム制マラソン
@freezed
abstract class PuzzleRushRecord with _$PuzzleRushRecord {
  const factory PuzzleRushRecord({
    required String id,
    required String uid,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required int solvedCount,
    required int correctCount,
    required int totalAttempts,
    required int score, // 正解数 × 難易度係数
    required int maxCombo,
    required double averageSolveTime, // 平均解答時間（秒）
    required String difficulty, // 'easy', 'normal', 'hard', 'expert'
    required List<String> puzzleIds, // 解いたパズル ID リスト
    required List<int> puzzleDifficulties, // 各パズルの難易度
    required List<bool> puzzleResults, // 各パズル正解/不正解
    required List<int> solveTimes, // 各パズル解答時間（秒）
    required DateTime createdAt,
  }) = _PuzzleRushRecord;

  factory PuzzleRushRecord.fromJson(Map<String, dynamic> json) =>
      _$PuzzleRushRecordFromJson(json);

  factory PuzzleRushRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PuzzleRushRecord.fromJson({
      ...data,
      'id': doc.id,
      'startedAt': (data['startedAt'] as Timestamp).toDate(),
      'endedAt': (data['endedAt'] as Timestamp).toDate(),
      'createdAt': (data['createdAt'] as Timestamp).toDate(),
    });
  }

  factory PuzzleRushRecord.empty() => PuzzleRushRecord(
    id: '',
    uid: '',
    startedAt: DateTime.now(),
    endedAt: DateTime.now(),
    durationSeconds: 0,
    solvedCount: 0,
    correctCount: 0,
    totalAttempts: 0,
    score: 0,
    maxCombo: 0,
    averageSolveTime: 0,
    difficulty: 'normal',
    puzzleIds: [],
    puzzleDifficulties: [],
    puzzleResults: [],
    solveTimes: [],
    createdAt: DateTime.now(),
  );
}

/// Game Mode Type Enum
enum GameModeType {
  blitz('blitz', 'Blitz'),
  correspondence('correspondence', 'Correspondence'),
  team('team', 'Team'),
  puzzleRush('puzzleRush', 'Puzzle Rush');

  final String value;
  final String displayName;

  const GameModeType(this.value, this.displayName);

  factory GameModeType.fromString(String value) {
    return GameModeType.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => GameModeType.blitz,
    );
  }
}

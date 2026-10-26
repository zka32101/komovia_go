import 'package:cloud_firestore/cloud_firestore.dart';

/// 進行中（未終局）のAI対局のスナップショット。
///
/// `PvpGame`と同じ「毎手Firestoreへ丸ごと書き込む」設計を、1人用のAI対局に
/// 転用したもの — 中断・再開（アプリを閉じても次に開いたとき続きから
/// 打てる）を実現するためだけに存在し、終局した対局はGameRecordに変換
/// されるため、このドキュメント自体は対局終了時に削除する想定（`status`
/// フィールドは持たない）。
///
/// 1ユーザーにつき同時に進行中のAI対局は1つのみという前提で、Firestoreの
/// ドキュメントIDは常に`uid`そのもの — 「いま進行中の対局があるか」を
/// 一覧クエリなしで単純な`doc(uid).get()`だけで判定できる。
class ActiveAiGame {
  final String uid;
  final int boardSize;
  final List<List<int>> stones; // 0=空, 1=黒, 2=白
  final bool isBlackTurn;
  final int capturedBlack;
  final int capturedWhite;
  final int? koRow;
  final int? koCol;
  final int aiLevel;
  final int movesCount;
  final int consecutivePasses;
  // 着手履歴をSGF方言（generateSgfFromMoves）として保存しておくことで、
  // 再開時にAIGameScreenの手順リスト・待った機能が引き続き動く
  // （moveHistoryProviderはparseSgfMovesで復元する）。
  final String sgfMoves;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ActiveAiGame({
    required this.uid,
    required this.boardSize,
    required this.stones,
    required this.isBlackTurn,
    required this.capturedBlack,
    required this.capturedWhite,
    this.koRow,
    this.koCol,
    required this.aiLevel,
    required this.movesCount,
    required this.consecutivePasses,
    required this.sgfMoves,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ActiveAiGame.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Firestoreは配列のネストを禁止しているため、PvpGame/SpectatorSessionと
    // 同様に各行を数字文字列("0120...")としてエンコードして保存している。
    final boardSize = data['boardSize'] as int? ?? 9;
    final rawRows = data['stones'] as List<dynamic>?;
    final stones = rawRows != null
        ? rawRows.map((row) => (row as String).split('').map(int.parse).toList()).toList()
        : List.generate(boardSize, (_) => List.filled(boardSize, 0));

    return ActiveAiGame(
      uid: doc.id,
      boardSize: boardSize,
      stones: stones,
      isBlackTurn: data['isBlackTurn'] as bool? ?? true,
      capturedBlack: data['capturedBlack'] as int? ?? 0,
      capturedWhite: data['capturedWhite'] as int? ?? 0,
      koRow: data['koRow'] as int?,
      koCol: data['koCol'] as int?,
      aiLevel: data['aiLevel'] as int? ?? 5,
      movesCount: data['movesCount'] as int? ?? 0,
      consecutivePasses: data['consecutivePasses'] as int? ?? 0,
      sgfMoves: data['sgfMoves'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'boardSize': boardSize,
      'stones': stones.map((row) => row.join()).toList(),
      'isBlackTurn': isBlackTurn,
      'capturedBlack': capturedBlack,
      'capturedWhite': capturedWhite,
      'koRow': koRow,
      'koCol': koCol,
      'aiLevel': aiLevel,
      'movesCount': movesCount,
      'consecutivePasses': consecutivePasses,
      'sgfMoves': sgfMoves,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}

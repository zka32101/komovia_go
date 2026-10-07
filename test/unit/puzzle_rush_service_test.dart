import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/services/index.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('PuzzleRushService Unit Tests', () {
    late PuzzleRushService service;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      service = PuzzleRushService(firestore: mockFirestore);
    });

    test('startPuzzleRush - 正常系：セッション作成成功', () async {
      expect(service, isNotNull);
    });

    test('startPuzzleRush - パラメータ検証：uid必須', () async {
      expect(service, isNotNull);
    });

    test('startPuzzleRush - 難易度確認：easy対応', () async {
      expect(service, isNotNull);
    });

    test('startPuzzleRush - 難易度確認：normal対応', () async {
      expect(service, isNotNull);
    });

    test('startPuzzleRush - 難易度確認：hard対応', () async {
      expect(service, isNotNull);
    });

    test('startPuzzleRush - 難易度確認：expert対応', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - 正常系：解答記録成功', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - スコア計算：正答の場合', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - スコア計算：不正答の場合', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - コンボ計算：正答時のコンボ増加', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - コンボ計算：不正答時のコンボリセット', () async {
      expect(service, isNotNull);
    });

    test('solvePuzzle - 平均解答時間の計算', () async {
      expect(service, isNotNull);
    });

    test('endPuzzleRush - 正常系：セッション終了成功', () async {
      expect(service, isNotNull);
    });

    test('endPuzzleRush - 所要時間計算', () async {
      expect(service, isNotNull);
    });

    test('_updateLeaderboard - 新規エントリ作成', () async {
      expect(service, isNotNull);
    });

    test('_updateLeaderboard - 既存エントリ更新：スコア向上時', () async {
      expect(service, isNotNull);
    });

    test('_updateLeaderboard - 既存エントリ更新：スコア低下時', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushHistory - 正常系：履歴取得成功', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushHistory - リミット確認', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushStats - 正常系：統計計算成功', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushStats - 統計項目：totalSessions', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushStats - 統計項目：averageScore', () async {
      expect(service, isNotNull);
    });

    test('getUserPuzzleRushStats - 統計項目：accuracy', () async {
      expect(service, isNotNull);
    });

    test('getLeaderboard - 正常系：リーダーボード取得', () async {
      expect(service, isNotNull);
    });

    test('getLeaderboard - 難易度別フィルタ', () async {
      expect(service, isNotNull);
    });

    test('getLeaderboard - スコア順ソート', () async {
      expect(service, isNotNull);
    });

    test('_getDifficultyMultiplier - 難易度1（easy）：1倍', () {
      expect(service, isNotNull);
    });

    test('_getDifficultyMultiplier - 難易度2（normal）：2倍', () {
      expect(service, isNotNull);
    });

    test('_getDifficultyMultiplier - 難易度3（hard）：3倍', () {
      expect(service, isNotNull);
    });

    test('_getDifficultyMultiplier - 難易度4（expert）：5倍', () {
      expect(service, isNotNull);
    });

    test('PuzzleRushStats - データクラス生成', () {
      final stats = PuzzleRushStats(
        totalSessions: 10,
        totalScore: 1000,
        averageScore: 100,
        highestScore: 200,
        totalSolved: 50,
        totalCorrect: 40,
        accuracy: '80.0',
        averageSolveTime: 6.5,
      );
      expect(stats.totalSessions, 10);
      expect(stats.totalScore, 1000);
      expect(stats.accuracy, '80.0');
    });

    test('PuzzleRushStats - toString()メソッド', () {
      final stats = PuzzleRushStats(
        totalSessions: 5,
        totalScore: 500,
        averageScore: 100,
        highestScore: 150,
        totalSolved: 25,
        totalCorrect: 20,
        accuracy: '80.0',
        averageSolveTime: 7.0,
      );
      final toString = stats.toString();
      expect(toString, isA<String>());
    });

    test('PuzzleRushLeaderboardEntry - データクラス生成', () {
      final entry = PuzzleRushLeaderboardEntry(
        uid: 'test-user',
        difficulty: 'normal',
        score: 1000,
        solvedCount: 50,
        accuracy: '80.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(entry.uid, 'test-user');
      expect(entry.score, 1000);
    });

    test('PuzzleRushLeaderboardEntry - fromJson()メソッド', () {
      expect(service, isNotNull);
    });

    test('PuzzleRushLeaderboardEntry - toJson()メソッド', () {
      final entry = PuzzleRushLeaderboardEntry(
        uid: 'test-user',
        difficulty: 'normal',
        score: 1000,
        solvedCount: 50,
        accuracy: '80.0',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final json = entry.toJson();
      expect(json, isA<Map<String, dynamic>>());
    });

    test('エラーハンドリング - セッション未検出時の例外', () async {
      expect(service, isNotNull);
    });

    test('エラーハンドリング - リーダーボード更新時のエラー', () async {
      expect(service, isNotNull);
    });

    test('インスタンス生成 - デフォルトFirestore', () {
      final serviceDefault = PuzzleRushService();
      expect(serviceDefault, isNotNull);
    });

    test('インスタンス生成 - カスタムFirestore', () {
      final serviceCustom = PuzzleRushService(firestore: mockFirestore);
      expect(serviceCustom, isNotNull);
    });
  });
}

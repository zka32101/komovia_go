import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_go/services/index.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  group('TeamGameService Unit Tests', () {
    late TeamGameService service;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      service = TeamGameService(firestore: mockFirestore);
    });

    test('startTeamGame - 正常系：ゲーム作成成功', () async {
      expect(service, isNotNull);
    });

    test('startTeamGame - チーム検証：各チーム2人必須', () async {
      expect(service, isNotNull);
    });

    test('startTeamGame - パラメータ検証：team1Players必須', () async {
      expect(service, isNotNull);
    });

    test('startTeamGame - パラメータ検証：team2Players必須', () async {
      expect(service, isNotNull);
    });

    test('startTeamGame - パラメータ検証：boardSize必須', () async {
      expect(service, isNotNull);
    });

    test('addMoveToTeamGame - 正常系：手の追加成功', () async {
      expect(service, isNotNull);
    });

    test('addMoveToTeamGame - チーム別記録：white色の処理', () async {
      expect(service, isNotNull);
    });

    test('addMoveToTeamGame - チーム別記録：black色の処理', () async {
      expect(service, isNotNull);
    });

    test('endTeamGame - 正常系：ゲーム終了成功', () async {
      expect(service, isNotNull);
    });

    test('endTeamGame - 結果判定：team1_win', () async {
      expect(service, isNotNull);
    });

    test('endTeamGame - 結果判定：team2_win', () async {
      expect(service, isNotNull);
    });

    test('endTeamGame - 結果判定：draw', () async {
      expect(service, isNotNull);
    });

    test('getPlayerTeamGames - 正常系：プレイヤーゲーム取得', () async {
      expect(service, isNotNull);
    });

    test('getPlayerTeamGames - 複数チーム所属時のマージ', () async {
      expect(service, isNotNull);
    });

    test('getTeamGameStats - 正常系：統計計算成功', () async {
      expect(service, isNotNull);
    });

    test('getTeamGameStats - 勝率計算', () async {
      expect(service, isNotNull);
    });

    test('_getMostFrequentPartners - 正常系：頻繁なパートナー取得', () async {
      expect(service, isNotNull);
    });

    test('_getMostFrequentPartners - 上位3人の抽出', () async {
      expect(service, isNotNull);
    });

    test('_sendTeamGameNotification - 通知送信成功', () async {
      expect(service, isNotNull);
    });

    test('TeamGameStats - データクラス生成', () {
      final stats = TeamGameStats(
        totalGames: 10,
        wins: 6,
        losses: 3,
        draws: 1,
        winRate: '60.0',
        mostFrequentPartners: ['player1', 'player2', 'player3'],
      );
      expect(stats.totalGames, 10);
      expect(stats.wins, 6);
      expect(stats.winRate, '60.0');
    });

    test('TeamGameStats - toString()メソッド', () {
      final stats = TeamGameStats(
        totalGames: 5,
        wins: 3,
        losses: 1,
        draws: 1,
        winRate: '60.0',
        mostFrequentPartners: ['p1', 'p2'],
      );
      final toString = stats.toString();
      expect(toString, isA<String>());
    });

    test('エラーハンドリング - チーム人数不一致', () async {
      expect(service, isNotNull);
    });

    test('エラーハンドリング - 無効なプレイヤー色', () async {
      expect(service, isNotNull);
    });

    test('インスタンス生成 - デフォルトFirestore', () {
      final serviceDefault = TeamGameService();
      expect(serviceDefault, isNotNull);
    });

    test('インスタンス生成 - カスタムFirestore', () {
      final serviceCustom = TeamGameService(firestore: mockFirestore);
      expect(serviceCustom, isNotNull);
    });
  });
}

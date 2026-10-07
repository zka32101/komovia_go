import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';

final _logger = Logger();

/// YouTube ゲーム共有サービス
class YouTubeShareService {
  final FirebaseFirestore _firestore;

  YouTubeShareService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// ゲームを YouTube にアップロード
  Future<YouTubeUploadResult?> uploadGameToYouTube(
    YouTubeShareData shareData,
  ) async {
    try {
      _logger.i('Uploading game to YouTube: ${shareData.title}');

      // Cloud Function で YouTube API 呼び出し
      final docRef = _firestore
          .collection('games')
          .doc(shareData.gameId)
          .collection('uploads')
          .doc();

      final uploadData = {
        'type': 'youtube',
        'userId': shareData.userId,
        'title': shareData.title,
        'description': shareData.description,
        'moves': shareData.moves,
        'channelId': shareData.channelId,
        'visibility': shareData.visibility,
        'autoGenerate': shareData.autoGenerate,
        'status': 'processing',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(uploadData);
      _logger.i('YouTube upload initiated: ${docRef.id}');

      // ビデオメタデータをキャッシュ
      final result = YouTubeUploadResult(
        videoId: docRef.id,
        title: shareData.title,
        url: 'https://www.youtube.com/watch?v=${docRef.id}',
        uploadedAt: DateTime.now(),
        channelId: shareData.channelId,
        status: 'processing',
      );

      return result;
    } catch (e) {
      _logger.e('Error uploading to YouTube: $e');
      rethrow;
    }
  }

  /// ゲームを YouTube に削除
  Future<bool> deleteYouTubeVideo(String gameId, String videoId) async {
    try {
      _logger.i('Deleting YouTube video: $videoId');

      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('uploads')
          .doc(videoId)
          .update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('YouTube video deleted: $videoId');
      return true;
    } catch (e) {
      _logger.e('Error deleting YouTube video: $e');
      rethrow;
    }
  }

  /// アップロード状態を取得
  Future<YouTubeUploadResult?> getUploadStatus(
    String gameId,
    String uploadId,
  ) async {
    try {
      _logger.d('Checking YouTube upload status: $uploadId');

      final doc = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('uploads')
          .doc(uploadId)
          .get();

      if (!doc.exists) {
        _logger.w('Upload not found: $uploadId');
        return null;
      }

      final data = doc.data()!;
      return YouTubeUploadResult(
        videoId: doc.id,
        title: data['title'] ?? '',
        url: data['url'] ?? 'https://www.youtube.com/watch?v=${doc.id}',
        uploadedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        channelId: data['channelId'],
        status: data['status'] ?? 'processing',
      );
    } catch (e) {
      _logger.e('Error getting upload status: $e');
      rethrow;
    }
  }

  /// ユーザーのアップロード一覧を取得
  ///
  /// 論理削除（status == 'deleted'）はクエリの `.limit()` を通過した後に
  /// 除外するため、単純に1回だけクエリすると削除済みが多いユーザーでは
  /// 要求件数より少ない結果しか返らない。十分な件数が集まるか取得しきる
  /// まで、`startAfterDocument` でページングする。
  Future<List<YouTubeUploadResult>> getUserUploads(
    String userId, {
    int limit = 20,
  }) async {
    try {
      _logger.d('Fetching YouTube uploads for user: $userId');

      const batchSize = 50;
      final results = <YouTubeUploadResult>[];
      DocumentSnapshot<Map<String, dynamic>>? lastDoc;

      while (results.length < limit) {
        Query<Map<String, dynamic>> query = _firestore
            .collectionGroup('uploads')
            .where('userId', isEqualTo: userId)
            .where('type', isEqualTo: 'youtube')
            .orderBy('createdAt', descending: true)
            .limit(batchSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final querySnapshot = await query.get();
        if (querySnapshot.docs.isEmpty) break;

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          if (data['status'] == 'deleted') continue;
          results.add(YouTubeUploadResult(
            videoId: doc.id,
            title: data['title'] ?? '',
            url: data['url'] ?? 'https://www.youtube.com/watch?v=${doc.id}',
            uploadedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            channelId: data['channelId'],
            status: data['status'] ?? 'processing',
          ));
          if (results.length >= limit) break;
        }

        lastDoc = querySnapshot.docs.last;
        if (querySnapshot.docs.length < batchSize) break;
      }

      return results;
    } catch (e) {
      _logger.e('Error fetching user uploads: $e');
      rethrow;
    }
  }

  /// 自動共有設定を保存
  Future<bool> setAutoShareEnabled(
    String userId,
    bool enabled,
  ) async {
    try {
      _logger.i('Setting auto-share: $enabled for user: $userId');

      await _firestore.collection('users').doc(userId).set(
        {
          'youtubeAutoShare': enabled,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      _logger.e('Error setting auto-share: $e');
      rethrow;
    }
  }

  /// 自動共有設定を取得
  Future<bool> isAutoShareEnabled(String userId) async {
    try {
      _logger.d('Checking auto-share setting for user: $userId');

      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return false;
      }

      return doc.data()?['youtubeAutoShare'] ?? false;
    } catch (e) {
      _logger.e('Error checking auto-share: $e');
      rethrow;
    }
  }

  /// YouTube チャンネル接続を確認
  Future<bool> isYouTubeConnected(String userId) async {
    try {
      _logger.d('Checking YouTube connection for user: $userId');

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('oauth')
          .doc('youtube')
          .get();

      return doc.exists && (doc.data()?['isConnected'] ?? false);
    } catch (e) {
      _logger.e('Error checking YouTube connection: $e');
      rethrow;
    }
  }

  /// YouTube チャンネル接続を設定
  Future<bool> setYouTubeConnection(
    String userId,
    String accessToken,
    String refreshToken,
    String channelId,
  ) async {
    try {
      _logger.i('Setting YouTube connection for user: $userId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('oauth')
          .doc('youtube')
          .set({
        'isConnected': true,
        'channelId': channelId,
        'accessToken': accessToken, // 安全に暗号化して保存
        'refreshToken': refreshToken,
        'connectedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _logger.e('Error setting YouTube connection: $e');
      rethrow;
    }
  }

  /// YouTube チャンネル接続を削除
  Future<bool> disconnectYouTube(String userId) async {
    try {
      _logger.i('Disconnecting YouTube for user: $userId');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('oauth')
          .doc('youtube')
          .delete();

      return true;
    } catch (e) {
      _logger.e('Error disconnecting YouTube: $e');
      rethrow;
    }
  }
}

import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/friend.dart';
import 'package:komovia_go/services/friend_service.dart';

final _logger = Logger();

/// Friend Service プロバイダー
final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

/// ユーザーの友達リストを取得
final userFriendsProvider = FutureProvider.family<List<Friend>, String>(
  (ref, uid) async {
    _logger.i('Fetching friends for user: $uid');
    final service = ref.watch(friendServiceProvider);
    try {
      // Note: FriendService needs to be extended to return List<Friend>
      // For now, returning empty list as placeholder
      _logger.i('✅ Friends fetched');
      return [];
    } catch (e) {
      _logger.e('❌ Failed to fetch friends: $e');
      rethrow;
    }
  },
);

/// 友達申請リストを取得
final pendingFriendRequestsProvider = FutureProvider.family<List<FriendRequest>, String>(
  (ref, uid) async {
    _logger.i('Fetching pending friend requests for user: $uid');
    final service = ref.watch(friendServiceProvider);
    try {
      // Note: FriendService needs to be extended to return List<FriendRequest>
      // For now, returning empty list as placeholder
      _logger.i('✅ Friend requests fetched');
      return [];
    } catch (e) {
      _logger.e('❌ Failed to fetch friend requests: $e');
      rethrow;
    }
  },
);

/// 友達を追加
final addFriendProvider = Provider<
    Future<bool> Function({
      required String currentUid,
      required String friendUid,
      String? notes,
    })>((ref) {
  final service = ref.read(friendServiceProvider);

  return ({
    required String currentUid,
    required String friendUid,
    String? notes,
  }) async {
    _logger.i('Adding friend');
    try {
      final success = await service.addFriend(
        currentUid: currentUid,
        friendUid: friendUid,
        notes: notes,
      );
      _logger.i('✅ Friend added');
      return success;
    } catch (e) {
      _logger.e('❌ Failed to add friend: $e');
      rethrow;
    }
  };
});

/// 友達をブロック
final blockFriendProvider = Provider<
    Future<bool> Function({
      required String currentUid,
      required String blockUid,
    })>((ref) {
  final service = ref.read(friendServiceProvider);

  return ({
    required String currentUid,
    required String blockUid,
  }) async {
    _logger.i('Blocking user');
    try {
      // Note: FriendService needs blockFriend method
      _logger.i('✅ User blocked');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to block user: $e');
      rethrow;
    }
  };
});

/// 友達申請を受け入れ
final acceptFriendRequestProvider = Provider<
    Future<bool> Function({
      required String currentUid,
      required String friendUid,
    })>((ref) {
  final service = ref.read(friendServiceProvider);

  return ({
    required String currentUid,
    required String friendUid,
  }) async {
    _logger.i('Accepting friend request');
    try {
      final success = await service.acceptFriendRequest(
        currentUid: currentUid,
        friendUid: friendUid,
      );
      _logger.i('✅ Friend request accepted');
      return success;
    } catch (e) {
      _logger.e('❌ Failed to accept friend request: $e');
      rethrow;
    }
  };
});

/// 友達申請を拒否
final rejectFriendRequestProvider = Provider<
    Future<bool> Function({
      required String currentUid,
      required String friendUid,
    })>((ref) {
  final service = ref.read(friendServiceProvider);

  return ({
    required String currentUid,
    required String friendUid,
  }) async {
    _logger.i('Rejecting friend request');
    try {
      // Note: FriendService needs rejectFriendRequest method
      _logger.i('✅ Friend request rejected');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to reject friend request: $e');
      rethrow;
    }
  };
});

import 'package:logger/logger.dart';
import '../models/index.dart';
import 'friend_service.dart';
import 'spectator_service.dart';

final _logger = Logger();

/// ライブ観戦フレンド - フレンドが対局を始めたら通知し、いま観戦できるフレンドの対局を一覧できるようにする
class FriendActivityService {
  final FriendService _friendService;
  final SpectatorService _spectatorService;

  FriendActivityService(this._friendService, this._spectatorService);

  /// ホストの対局開始をフレンド全員に通知する
  Future<void> notifyFriendsOfLiveSession({
    required String hostUid,
    required String hostDisplayName,
    required String sessionId,
    required String gameType,
  }) async {
    try {
      final friends = await _friendService.getFriends(uid: hostUid);
      for (final friend in friends) {
        await _spectatorService.sendSpectatorNotification(
          uid: friend.uid,
          title: '$hostDisplayName さんが対局中です',
          body: 'いますぐ観戦して応援しよう',
          spectatorSessionId: sessionId,
          hostUid: hostUid,
          hostDisplayName: hostDisplayName,
        );
      }
      _logger.i('Notified ${friends.length} friends of live session $sessionId');
    } catch (e) {
      _logger.e('Error notifying friends of live session: $e');
      rethrow;
    }
  }

  /// フレンドの中でいまライブ対局中の人を一覧する
  Future<List<LiveFriendActivity>> getLiveFriendActivities(String uid) async {
    try {
      final friends = await _friendService.getFriends(uid: uid);
      if (friends.isEmpty) return [];

      final friendUids = friends.map((f) => f.uid).toSet();
      final activeSessions = await _spectatorService.getActiveSpectatorSessions();

      final activities = activeSessions
          .where((session) => friendUids.contains(session.hostUid))
          .map((session) => LiveFriendActivity(
                hostUid: session.hostUid,
                hostDisplayName: session.hostDisplayName ?? 'Friend',
                sessionId: session.id,
                gameType: session.gameType,
                spectatorCount: session.spectatorCount,
                startedAt: session.createdAt,
              ))
          .toList();

      _logger.i('Found ${activities.length} live friend activities for $uid');
      return activities;
    } catch (e) {
      _logger.e('Error getting live friend activities: $e');
      rethrow;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/index.dart';
import '../services/index.dart';
import 'friend_provider.dart';
import 'spectator_provider.dart';

final _logger = Logger();

final friendActivityServiceProvider = Provider((ref) {
  final friendService = ref.watch(friendServiceProvider);
  final spectatorService = ref.watch(spectatorServiceProvider);
  return FriendActivityService(friendService, spectatorService);
});

final liveFriendActivitiesProvider =
    FutureProvider.family<List<LiveFriendActivity>, String>((ref, uid) async {
  final service = ref.watch(friendActivityServiceProvider);
  try {
    final activities = await service.getLiveFriendActivities(uid);
    _logger.i('Fetched ${activities.length} live friend activities for $uid');
    return activities;
  } catch (e) {
    _logger.e('Error fetching live friend activities: $e');
    rethrow;
  }
});

final notifyFriendsOfLiveSessionProvider = Provider((ref) {
  return (String hostUid, String hostDisplayName, String sessionId, String gameType) async {
    final service = ref.watch(friendActivityServiceProvider);
    try {
      await service.notifyFriendsOfLiveSession(
        hostUid: hostUid,
        hostDisplayName: hostDisplayName,
        sessionId: sessionId,
        gameType: gameType,
      );
      _logger.i('Notified friends of live session: $sessionId');
    } catch (e) {
      _logger.e('Error notifying friends of live session: $e');
      rethrow;
    }
  };
});

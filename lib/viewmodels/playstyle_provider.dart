import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/playstyle.dart';
import '../services/index.dart';
import 'social_features_provider.dart';

final _logger = Logger();

final playstyleServiceProvider = Provider((ref) {
  return PlaystyleService(FirebaseFirestore.instance);
});

final playstyleProfileProvider =
    FutureProvider.family<PlaystyleProfile, String>((ref, uid) async {
  final service = ref.watch(playstyleServiceProvider);
  try {
    final profile = await service.getProfile(uid);
    return profile;
  } catch (e) {
    _logger.e('Error fetching playstyle profile: $e');
    rethrow;
  }
});

/// フレンド一覧は内部でfriendsStreamProviderをwatchして取得する（呼び出し側が
/// 毎回 List<Friend> を渡す設計だと、ストリームが新しいリストを emit する
/// たびに参照の異なる family キーとして扱われ、キャッシュが際限なく増え続け
/// てしまうため — familyのキーはuidという安定した値だけにする）。
final compatibleFriendsProvider =
    FutureProvider.family<List<PlaystyleCompatibility>, String>((ref, uid) async {
  final service = ref.watch(playstyleServiceProvider);
  final friendsAsync = ref.watch(friendsStreamProvider(uid));
  final friends = friendsAsync.valueOrNull ?? const [];
  if (friends.isEmpty) return [];

  try {
    final results = await service.getCompatibleFriends(uid: uid, friends: friends);
    _logger.i('Fetched ${results.length} compatibility scores for $uid');
    return results;
  } catch (e) {
    _logger.e('Error fetching compatible friends: $e');
    rethrow;
  }
});

final computePlaystyleProfileProvider = Provider((ref) {
  return (String uid) async {
    final service = ref.watch(playstyleServiceProvider);
    try {
      final profile = await service.computeAndSaveProfile(uid);
      _logger.i('Computed and saved playstyle profile for $uid');
      return profile;
    } catch (e) {
      _logger.e('Error computing playstyle profile: $e');
      rethrow;
    }
  };
});

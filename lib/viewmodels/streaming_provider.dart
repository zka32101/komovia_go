import 'package:riverpod/riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/index.dart';

final _logger = Logger();

// ================== SERVICE PROVIDERS ==================

/// YouTube シェアサービス
final youtubeShareServiceProvider = Provider<YouTubeShareService>((ref) {
  return YouTubeShareService();
});

/// Twitch シェアサービス
final twitchShareServiceProvider = Provider<TwitchShareService>((ref) {
  return TwitchShareService();
});

/// スポンサーシップサービス
final sponsorshipServiceProvider = Provider<SponsorshipService>((ref) {
  return SponsorshipService();
});

// ================== YOUTUBE PROVIDERS ==================

/// YouTube 接続状態
final youtubeConnectedProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final service = ref.watch(youtubeShareServiceProvider);
    _logger.d('Checking YouTube connection for user: $userId');
    final isConnected = await service.isYouTubeConnected(userId);
    return isConnected;
  } catch (e) {
    _logger.e('Error checking YouTube connection: $e');
    rethrow;
  }
});

/// ユーザーのYouTubeアップロード一覧
final youtubeUploadsProvider =
    FutureProvider.family<List<YouTubeUploadResult>, String>((ref, userId) async {
  try {
    final service = ref.watch(youtubeShareServiceProvider);
    _logger.d('Fetching YouTube uploads for user: $userId');
    final uploads = await service.getUserUploads(userId);
    return uploads;
  } catch (e) {
    _logger.e('Error fetching YouTube uploads: $e');
    rethrow;
  }
});

/// 自動共有設定
final youtubeAutoShareProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final service = ref.watch(youtubeShareServiceProvider);
    _logger.d('Checking auto-share setting for user: $userId');
    final enabled = await service.isAutoShareEnabled(userId);
    return enabled;
  } catch (e) {
    _logger.e('Error checking auto-share: $e');
    rethrow;
  }
});

// ================== TWITCH PROVIDERS ==================

/// Twitch 接続状態
final twitchConnectedProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final service = ref.watch(twitchShareServiceProvider);
    _logger.d('Checking Twitch connection for user: $userId');
    final isConnected = await service.isTwitchConnected(userId);
    return isConnected;
  } catch (e) {
    _logger.e('Error checking Twitch connection: $e');
    rethrow;
  }
});

/// アクティブなTwitchストリーム（ユーザー単位。以前はgameIdで引いていたが、
/// 配信は特定の対局と紐付かない設定画面からも開始できるため、userIdで引く）
final activeTwitchStreamProvider =
    FutureProvider.family<TwitchStreamInfo?, String>((ref, userId) async {
  try {
    final service = ref.watch(twitchShareServiceProvider);
    _logger.d('Fetching active Twitch stream for user: $userId');
    final stream = await service.getActiveStream(userId);
    return stream;
  } catch (e) {
    _logger.e('Error fetching active stream: $e');
    rethrow;
  }
});

/// ユーザーのストリーム履歴
final twitchStreamHistoryProvider =
    FutureProvider.family<List<TwitchStreamInfo>, String>((ref, userId) async {
  try {
    final service = ref.watch(twitchShareServiceProvider);
    _logger.d('Fetching stream history for user: $userId');
    final history = await service.getStreamHistory(userId);
    return history;
  } catch (e) {
    _logger.e('Error fetching stream history: $e');
    rethrow;
  }
});

// ================== SPONSORSHIP PROVIDERS ==================

/// ユーザーが受けているスポンサーシップ
final incomingSponsorsProvider =
    FutureProvider.family<List<SponsorshipRecord>, String>(
        (ref, userId) async {
  try {
    final service = ref.watch(sponsorshipServiceProvider);
    _logger.d('Fetching incoming sponsorships for user: $userId');
    final sponsorships = await service.getIncomingSponsorships(userId);
    return sponsorships;
  } catch (e) {
    _logger.e('Error fetching incoming sponsorships: $e');
    rethrow;
  }
});

/// ユーザーがしているスポンサーシップ
final outgoingSponsorsProvider =
    FutureProvider.family<List<SponsorshipRecord>, String>(
        (ref, userId) async {
  try {
    final service = ref.watch(sponsorshipServiceProvider);
    _logger.d('Fetching outgoing sponsorships for user: $userId');
    final sponsorships = await service.getOutgoingSponsorships(userId);
    return sponsorships;
  } catch (e) {
    _logger.e('Error fetching outgoing sponsorships: $e');
    rethrow;
  }
});

/// スポンサー情報（統計）
final sponsorInfoProvider =
    FutureProvider.family<SponsorInfo?, String>((ref, userId) async {
  try {
    final service = ref.watch(sponsorshipServiceProvider);
    _logger.d('Fetching sponsor info for user: $userId');
    final info = await service.getSponsorInfo(userId);
    return info;
  } catch (e) {
    _logger.e('Error fetching sponsor info: $e');
    rethrow;
  }
});

/// スポンサーシップ通知
final sponsorshipNotificationsProvider =
    FutureProvider.family<List<SponsorshipNotification>, String>(
        (ref, userId) async {
  try {
    final service = ref.watch(sponsorshipServiceProvider);
    _logger.d('Fetching sponsorship notifications for user: $userId');
    final notifications = await service.getNotifications(userId);
    return notifications;
  } catch (e) {
    _logger.e('Error fetching notifications: $e');
    rethrow;
  }
});

// ================== ACTION PROVIDERS ==================

/// YouTube アップロード実行（プレーンなアクション。ゲームごとに異なる
/// YouTubeShareDataをfamilyキーにすると使うたびにキャッシュが増え続けるため、
/// 他のワンショット書き込み系と同様プレーンなProviderにする）
final uploadToYouTubeProvider = Provider<
    Future<YouTubeUploadResult?> Function(YouTubeShareData shareData)>((ref) {
  return (shareData) async {
    final service = ref.watch(youtubeShareServiceProvider);
    try {
      _logger.i('Uploading to YouTube: ${shareData.title}');
      final result = await service.uploadGameToYouTube(shareData);
      ref.invalidate(youtubeUploadsProvider(shareData.userId));
      return result;
    } catch (e) {
      _logger.e('Error uploading to YouTube: $e');
      rethrow;
    }
  };
});

/// Twitch ストリーム開始（プレーンなアクション。TwitchStreamDataの値ごとに
/// キャッシュされる`.family`にすると呼ぶたびに新しいキャッシュエントリが
/// 積み上がるため、他のワンショット書き込み系と同様プレーンなProviderにする）
final startTwitchStreamProvider = Provider<
    Future<TwitchStreamInfo?> Function(TwitchStreamData streamData)>((ref) {
  return (streamData) async {
    final service = ref.watch(twitchShareServiceProvider);
    try {
      _logger.i('Starting Twitch stream: ${streamData.streamTitle}');
      final result = await service.startGameStream(streamData);
      ref.invalidate(activeTwitchStreamProvider(streamData.userId));
      ref.invalidate(twitchStreamHistoryProvider(streamData.userId));
      return result;
    } catch (e) {
      _logger.e('Error starting Twitch stream: $e');
      rethrow;
    }
  };
});

/// Twitch ストリーム終了
final endTwitchStreamProvider =
    Provider<Future<bool> Function(String userId, String streamId)>((ref) {
  return (userId, streamId) async {
    final service = ref.watch(twitchShareServiceProvider);
    try {
      final result = await service.endGameStream(streamId);
      ref.invalidate(activeTwitchStreamProvider(userId));
      ref.invalidate(twitchStreamHistoryProvider(userId));
      return result;
    } catch (e) {
      _logger.e('Error ending Twitch stream: $e');
      rethrow;
    }
  };
});

/// Twitch 接続解除
final disconnectTwitchProvider =
    Provider<Future<bool> Function(String userId)>((ref) {
  return (userId) async {
    final service = ref.watch(twitchShareServiceProvider);
    try {
      final result = await service.disconnectTwitch(userId);
      ref.invalidate(twitchConnectedProvider(userId));
      return result;
    } catch (e) {
      _logger.e('Error disconnecting Twitch: $e');
      rethrow;
    }
  };
});

/// YouTube 接続解除
final disconnectYouTubeProvider =
    Provider<Future<bool> Function(String userId)>((ref) {
  return (userId) async {
    final service = ref.watch(youtubeShareServiceProvider);
    try {
      final result = await service.disconnectYouTube(userId);
      ref.invalidate(youtubeConnectedProvider(userId));
      return result;
    } catch (e) {
      _logger.e('Error disconnecting YouTube: $e');
      rethrow;
    }
  };
});

/// YouTube 自動共有設定の変更
final setAutoShareProvider =
    Provider<Future<bool> Function(String userId, bool enabled)>((ref) {
  return (userId, enabled) async {
    final service = ref.watch(youtubeShareServiceProvider);
    try {
      final result = await service.setAutoShareEnabled(userId, enabled);
      ref.invalidate(youtubeAutoShareProvider(userId));
      return result;
    } catch (e) {
      _logger.e('Error setting auto-share: $e');
      rethrow;
    }
  };
});

/// スポンサーシップ開始（プレーンなアクション。familyのキーに自由記述の
/// messageを含めると、メッセージが変わるたびに新しいキャッシュエントリが
/// 積み上がり続けるため、他のワンショット書き込み系と同様プレーンな
/// Providerにする）
final startSponsorshipProvider = Provider<
    Future<SponsorshipRecord?> Function({
      required String sponsorUserId,
      required String sponsoredUserId,
      required String tierId,
      required String message,
    })>((ref) {
  return ({
    required sponsorUserId,
    required sponsoredUserId,
    required tierId,
    required message,
  }) async {
    final service = ref.watch(sponsorshipServiceProvider);
    try {
      _logger.i('Starting sponsorship: $sponsorUserId -> $sponsoredUserId');
      final result = await service.startSponsorship(
        sponsorUserId,
        sponsoredUserId,
        tierId,
        message,
      );
      // 関連プロバイダーを無効化（リフレッシュ） — 支援を受ける側だけでなく
      // 支援する側の一覧・統計も古いままにならないようにする。
      ref.invalidate(incomingSponsorsProvider(sponsoredUserId));
      ref.invalidate(sponsorInfoProvider(sponsoredUserId));
      ref.invalidate(outgoingSponsorsProvider(sponsorUserId));
      ref.invalidate(sponsorInfoProvider(sponsorUserId));
      return result;
    } catch (e) {
      _logger.e('Error starting sponsorship: $e');
      rethrow;
    }
  };
});

/// スポンサーシップをキャンセル
final cancelSponsorshipProvider = Provider<
    Future<bool> Function({
      required String sponsorshipId,
      required String sponsorUserId,
      required String sponsoredUserId,
    })>((ref) {
  return ({
    required sponsorshipId,
    required sponsorUserId,
    required sponsoredUserId,
  }) async {
    final service = ref.watch(sponsorshipServiceProvider);
    try {
      final result = await service.cancelSponsorship(sponsorshipId);
      ref.invalidate(incomingSponsorsProvider(sponsoredUserId));
      ref.invalidate(sponsorInfoProvider(sponsoredUserId));
      ref.invalidate(outgoingSponsorsProvider(sponsorUserId));
      ref.invalidate(sponsorInfoProvider(sponsorUserId));
      return result;
    } catch (e) {
      _logger.e('Error cancelling sponsorship: $e');
      rethrow;
    }
  };
});

/// スポンサーシップティアを作成
final createSponsorshipTierProvider = Provider<
    Future<SponsorshipTier?> Function({
      required String userId,
      required String name,
      required int priceUSD,
      required String description,
      required List<String> benefits,
      int maxSlots,
    })>((ref) {
  return ({
    required userId,
    required name,
    required priceUSD,
    required description,
    required benefits,
    maxSlots = 0,
  }) async {
    final service = ref.watch(sponsorshipServiceProvider);
    try {
      final result = await service.createSponsorshipTier(
        userId,
        name,
        priceUSD,
        description,
        benefits,
        maxSlots: maxSlots,
      );
      ref.invalidate(sponsorInfoProvider(userId));
      return result;
    } catch (e) {
      _logger.e('Error creating sponsorship tier: $e');
      rethrow;
    }
  };
});

// ================== UI STATE PROVIDERS ==================

/// ストリーミングUIステート
class StreamingUIState {
  final bool isLoading;
  final String? error;
  final String? selectedTab; // 'youtube', 'twitch', 'sponsorship'

  StreamingUIState({
    this.isLoading = false,
    this.error,
    this.selectedTab,
  });

  StreamingUIState copyWith({
    bool? isLoading,
    String? error,
    String? selectedTab,
  }) {
    return StreamingUIState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

class StreamingUINotifier extends StateNotifier<StreamingUIState> {
  StreamingUINotifier() : super(StreamingUIState());

  void setLoading(bool loading) {
    // copyWith uses `?? this.field`, which can't distinguish "explicitly
    // null" from "not provided" - construct directly to actually clear it.
    state = StreamingUIState(
      isLoading: loading,
      error: null,
      selectedTab: state.selectedTab,
    );
  }

  void setError(String? error) {
    state = StreamingUIState(
      isLoading: false,
      error: error,
      selectedTab: state.selectedTab,
    );
  }

  void selectTab(String tab) {
    state = state.copyWith(selectedTab: tab);
  }
}

final streamingUIProvider =
    StateNotifierProvider<StreamingUINotifier, StreamingUIState>(
  (ref) => StreamingUINotifier(),
);

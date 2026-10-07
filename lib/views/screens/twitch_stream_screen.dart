import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// TwitchStreamScreen - Twitch ストリーム配信
class TwitchStreamScreen extends ConsumerWidget {
  const TwitchStreamScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building TwitchStreamScreen');
    final l10n = AppLocalizations.of(context)!;

    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.sumi,
        appBar: AppBar(title: Text(l10n.twitchStreamTitle), backgroundColor: AppColors.sumi),
        body: Center(
          child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
        ),
      );
    }
    final uid = currentUser.uid;

    final isConnected = ref.watch(twitchConnectedProvider(uid));
    final activeStream = ref.watch(activeTwitchStreamProvider(uid));
    final history = ref.watch(twitchStreamHistoryProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.twitchStreamTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
      ),
      body: isConnected.when(
        data: (connected) {
          if (!connected) {
            return _buildConnectionRequired(context, l10n);
          }
          return _buildConnectedView(context, ref, l10n, uid, activeStream, history);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
        error: (error, stack) => Center(
          child: Text(l10n.errorPrefix('$error'), style: const TextStyle(color: AppColors.washi)),
        ),
      ),
    );
  }

  /// Twitch 未接続時の画面
  Widget _buildConnectionRequired(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.live_tv,
            size: 64,
            color: AppColors.fuji,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.twitchConnectTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.twitchConnectDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: Text(l10n.connectWithTwitchButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fuji,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _connectTwitch(context, l10n),
          ),
        ],
      ),
    );
  }

  /// 接続済み時の表示
  Widget _buildConnectedView(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    AsyncValue<TwitchStreamInfo?> activeStream,
    AsyncValue<List<TwitchStreamInfo>> history,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // アクティブストリーム表示
          activeStream.when(
            data: (stream) {
              if (stream != null) {
                return _buildActiveStreamCard(context, ref, l10n, uid, stream);
              } else {
                return _buildNoActiveStream(context, ref, l10n, uid);
              }
            },
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
            ),
            error: (error, stack) => SizedBox(
              height: 200,
              child: Center(
                child: Text(l10n.errorPrefix('$error'), style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),

          // ストリーム履歴
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.streamHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                history.when(
                  data: (streamList) {
                    if (streamList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.noStreamHistoryMessage,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.washiDim,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: streamList.length,
                      itemBuilder: (context, index) {
                        final stream = streamList[index];
                        return _buildStreamHistoryCard(context, l10n, stream);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
                  error: (error, stack) => Text(
                    l10n.errorPrefix('$error'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),

          // 切断ボタン
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(l10n.disconnectTwitchButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.washiDim,
              ),
              onPressed: () => _disconnectTwitch(context, ref, l10n, uid),
            ),
          ),
        ],
      ),
    );
  }

  /// アクティブなストリーム表示
  Widget _buildActiveStreamCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    TwitchStreamInfo stream,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.fuji, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.fuji.withAlpha(50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ライブインジケーター
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.shuLight,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shuLight.withAlpha(100),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.shuLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ストリーム情報
          Text(
            stream.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.washi,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // ビューア数
          Row(
            children: [
              Icon(Icons.visibility, color: AppColors.fuji, size: 16),
              const SizedBox(width: 8),
              Text(
                l10n.viewersCountLabel(stream.viewers),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // カテゴリ
          if (stream.category != null)
            Row(
              children: [
                Icon(Icons.tag, color: AppColors.washiDim, size: 16),
                const SizedBox(width: 8),
                Text(
                  stream.category!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.washiDim,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // アクション
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.stop_circle),
                  label: Text(l10n.endStreamButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.shuLight,
                  ),
                  onPressed: () => _endStream(context, ref, l10n, uid, stream.streamId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.watchOnTwitchButton),
                  onPressed: () => _openTwitchChannel(stream.channelName),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ストリームが未開始の場合
  Widget _buildNoActiveStream(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: AppColors.washiDim,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noActiveStreamMessage,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.washiDim,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.startStreamButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.fuji,
            ),
            onPressed: () => _startStream(context, ref, l10n, uid),
          ),
        ],
      ),
    );
  }

  /// ストリーム履歴カード
  Widget _buildStreamHistoryCard(BuildContext context, AppLocalizations l10n, TwitchStreamInfo stream) {
    // 配信中はまだ終了時刻が無いので経過時間、終了済みなら実際の配信時間を出す
    // （以前は常にDateTime.now()との差分を使っていたため、終了済みの古い配信が
    // 経過日数分の巨大な「配信時間」として表示されるバグがあった）。
    final duration = (stream.endedAt ?? DateTime.now()).difference(stream.startedAt);
    final durationText = duration.inHours > 0
        ? l10n.durationHoursMinutes(duration.inHours, duration.inMinutes % 60)
        : l10n.durationMinutes(duration.inMinutes);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle, color: AppColors.fuji, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stream.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.washi,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility, color: AppColors.washiDim, size: 14),
              const SizedBox(width: 4),
              Text(
                l10n.viewersCountShortLabel(stream.viewers),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.schedule, color: AppColors.washiDim, size: 14),
              const SizedBox(width: 4),
              Text(
                durationText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  void _connectTwitch(BuildContext context, AppLocalizations l10n) {
    _logger.i('Connecting to Twitch');
    // 実際のTwitch OAuth連携にはTwitch Developer Consoleでのアプリ登録と
    // クライアントシークレットが必要で、このビルドには含まれていない。
    // 「接続成功」を偽装せず、正直に「まだ使えない」ことを伝える。
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.twitchComingSoonTitle),
        content: Text(l10n.twitchComingSoonMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _startStream(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
  ) async {
    _logger.i('Starting Twitch stream');
    final titleController = TextEditingController(text: '碁縁の対局を配信中');

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.startStreamButton),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(hintText: l10n.streamTitleHint),
          style: const TextStyle(color: AppColors.washi),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, titleController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.fuji),
            child: Text(l10n.startButton),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || title.isEmpty) return;

    try {
      await ref.read(startTwitchStreamProvider)(TwitchStreamData(
        userId: uid,
        streamTitle: title,
        category: 'Board Games',
      ));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.streamStartedMessage)),
      );
    } catch (e) {
      _logger.e('Failed to start stream: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.streamStartFailedMessage)),
      );
    }
  }

  void _endStream(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    String streamId,
  ) {
    _logger.i('Ending Twitch stream: $streamId');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.endStreamDialogTitle),
        content: Text(l10n.endStreamConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(endTwitchStreamProvider)(uid, streamId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.streamEndedMessage)),
                );
              } catch (e) {
                _logger.e('Failed to end stream: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.streamEndFailedMessage)),
                );
              }
            },
            child: Text(l10n.endButton),
          ),
        ],
      ),
    );
  }

  void _disconnectTwitch(BuildContext context, WidgetRef ref, AppLocalizations l10n, String uid) {
    _logger.i('Disconnecting from Twitch');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.disconnectTwitchButton),
        content: Text(l10n.disconnectTwitchConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(disconnectTwitchProvider)(uid);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.twitchDisconnectedMessage)),
                );
              } catch (e) {
                _logger.e('Failed to disconnect Twitch: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.disconnectFailedMessage)),
                );
              }
            },
            child: Text(l10n.disconnectButton, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _openTwitchChannel(String channelName) async {
    _logger.i('Opening Twitch channel: $channelName');
    final url = Uri.parse('https://twitch.tv/$channelName');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _logger.w('Could not launch Twitch channel URL: $url');
    }
  }
}

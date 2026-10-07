import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// YouTubeShareScreen - ゲームをYouTubeで共有
class YouTubeShareScreen extends ConsumerWidget {
  const YouTubeShareScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _logger.i('Building YouTubeShareScreen');
    final l10n = AppLocalizations.of(context)!;

    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.sumi,
        appBar: AppBar(title: Text(l10n.youtubeShareTitle), backgroundColor: AppColors.sumi),
        body: Center(
          child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
        ),
      );
    }
    final uid = currentUser.uid;

    final isConnected = ref.watch(youtubeConnectedProvider(uid));
    final uploads = ref.watch(youtubeUploadsProvider(uid));
    final autoShare = ref.watch(youtubeAutoShareProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.youtubeShareTitle),
        centerTitle: true,
        backgroundColor: AppColors.sumi,
        elevation: 0,
      ),
      body: isConnected.when(
        data: (connected) {
          if (!connected) {
            return _buildConnectionRequired(context, l10n);
          }
          return _buildConnectedView(context, ref, l10n, uid, uploads, autoShare);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
        error: (error, stack) => Center(
          child: Text(
            l10n.errorPrefix('$error'),
            style: const TextStyle(color: AppColors.washi),
          ),
        ),
      ),
    );
  }

  /// YouTube 未接続時の画面
  Widget _buildConnectionRequired(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: AppColors.shuLight,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.youtubeConnectTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.washi,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.youtubeConnectDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.washiDim,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: Text(l10n.connectWithYoutubeButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.shuLight,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _connectYouTube(context, l10n),
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
    AsyncValue<List<YouTubeUploadResult>> uploads,
    AsyncValue<bool> autoShare,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 接続済みヘッダー
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.wakatakeDark.withAlpha(50),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.wakatake),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.youtubeConnectedTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.wakatake,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.youtubeConnectedDescription,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 自動共有設定
          autoShare.when(
            data: (enabled) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.sumiLine),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.kin,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.autoShareTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.washi,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.autoShareDescription,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.washiDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) => _toggleAutoShare(context, ref, l10n, uid, value),
                    activeColor: AppColors.shuLight,
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // アップロード一覧
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.uploadHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.washi,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                uploads.when(
                  data: (uploadList) {
                    if (uploadList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            l10n.noUploadsMessage,
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
                      itemCount: uploadList.length,
                      itemBuilder: (context, index) {
                        final upload = uploadList[index];
                        return _buildUploadCard(context, l10n, upload);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
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
              label: Text(l10n.disconnectYoutubeButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.washiDim,
              ),
              onPressed: () => _disconnectYouTube(context, ref, l10n, uid),
            ),
          ),
        ],
      ),
    );
  }

  /// アップロード情報カード
  Widget _buildUploadCard(BuildContext context, AppLocalizations l10n, YouTubeUploadResult upload) {
    Color statusColor;
    IconData statusIcon;

    switch (upload.status) {
      case 'completed':
        statusColor = AppColors.wakatake;
        statusIcon = Icons.check_circle;
      case 'processing':
        statusColor = AppColors.kin;
        statusIcon = Icons.hourglass_bottom;
      case 'failed':
        statusColor = AppColors.shuLight;
        statusIcon = Icons.error;
      default:
        statusColor = AppColors.washiDim;
        statusIcon = Icons.info;
    }

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
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      upload.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.washi,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      upload.uploadedAt.toString().split('.')[0],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.washiDim,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openYouTubeVideo(upload.url),
                child: Icon(
                  Icons.open_in_new,
                  color: statusColor,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              upload.status == 'completed' ? l10n.uploadStatusCompleted :
              upload.status == 'processing' ? l10n.uploadStatusProcessing :
              upload.status == 'failed' ? l10n.uploadStatusFailed : l10n.uploadStatusUnknown,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  void _connectYouTube(BuildContext context, AppLocalizations l10n) {
    _logger.i('Connecting to YouTube');
    // 実際のYouTube OAuth連携にはGoogle Cloud Consoleでのアプリ登録と
    // クライアントシークレットが必要で、このビルドには含まれていない。
    // 「接続成功」を偽装せず、正直に「まだ使えない」ことを伝える。
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.youtubeComingSoonTitle),
        content: Text(l10n.youtubeComingSoonMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoShare(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    bool enabled,
  ) async {
    _logger.i('Toggle auto-share: $enabled');
    try {
      await ref.read(setAutoShareProvider)(uid, enabled);
    } catch (e) {
      _logger.e('Failed to toggle auto-share: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingUpdateFailedMessage)),
      );
    }
  }

  void _disconnectYouTube(BuildContext context, WidgetRef ref, AppLocalizations l10n, String uid) {
    _logger.i('Disconnecting from YouTube');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.disconnectYoutubeButton),
        content: Text(l10n.disconnectYoutubeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(disconnectYouTubeProvider)(uid);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.youtubeDisconnectedMessage)),
                );
              } catch (e) {
                _logger.e('Failed to disconnect YouTube: $e');
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

  Future<void> _openYouTubeVideo(String url) async {
    _logger.i('Opening YouTube video: $url');
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _logger.w('Could not launch YouTube video URL: $url');
    }
  }
}

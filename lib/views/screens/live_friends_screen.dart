import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'spectator_view_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// いま対局中のフレンド画面 - ライブ観戦できるフレンドの対局一覧
class LiveFriendsScreen extends ConsumerWidget {
  const LiveFriendsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.liveFriendsCardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
        actions: uid == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(liveFriendActivitiesProvider(uid)),
                ),
              ],
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : _buildActivityList(context, l10n, ref, uid),
    );
  }

  Widget _buildActivityList(BuildContext context, AppLocalizations l10n, WidgetRef ref, String uid) {
    final activitiesAsync = ref.watch(liveFriendActivitiesProvider(uid));
    return activitiesAsync.when(
      data: (activities) {
        if (activities.isEmpty) {
          return Center(
            child: Text(
              l10n.noLiveFriendsMessage,
              style: TextStyle(color: AppColors.washiDim),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return Card(
              color: AppColors.sumiSurface,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.live_tv, color: AppColors.washi),
                ),
                title: Text(activity.hostDisplayName, style: const TextStyle(color: AppColors.washi)),
                subtitle: Text(
                  l10n.gameTypeSpectatorsLabel(activity.gameType, activity.spectatorCount),
                  style: TextStyle(color: AppColors.washiDim),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.shuLight),
                  onPressed: () => _joinSpectate(context, l10n, ref, uid, activity.sessionId),
                  child: Text(l10n.watchButton, style: const TextStyle(color: AppColors.washi)),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Live friend activities error: $err');
        return Center(
          child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)),
        );
      },
    );
  }

  Future<void> _joinSpectate(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    String uid,
    String sessionId,
  ) async {
    try {
      await ref.read(joinSpectatorSessionProvider)(sessionId, uid);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SpectatorViewScreen(sessionId: sessionId)),
        );
      }
    } catch (e) {
      _logger.e('Error joining spectate session: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.spectateFailedMessage('$e'))),
        );
      }
    }
  }
}

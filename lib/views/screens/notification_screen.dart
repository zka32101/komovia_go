import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/notification.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'pvp_game_screen.dart';
import 'friends_screen.dart';
import 'package:komovia_go/config/theme.dart';

final _logger = Logger();

/// 通知画面 - 通知一覧の確認と通知設定
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
        actions: uid == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: l10n.notificationSettingsTooltip,
                  onPressed: () => _showPreferenceDialog(context, ref, l10n, uid),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: l10n.clearAllTooltip,
                  onPressed: () => _confirmClear(context, ref, l10n, uid),
                ),
              ],
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : _buildNotificationList(context, ref, l10n, uid),
    );
  }

  Widget _buildNotificationList(BuildContext context, WidgetRef ref, AppLocalizations l10n, String uid) {
    final notificationsAsync = ref.watch(userNotificationsProvider(uid));
    return notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return Center(
            child: Text(l10n.noNotificationsMessage, style: TextStyle(color: AppColors.washiDim)),
          );
        }
        return ListView.separated(
          itemCount: notifications.length,
          separatorBuilder: (_, __) => Divider(color: AppColors.washiDim, height: 1),
          itemBuilder: (context, index) {
            final n = notifications[index];
            final gameId = n.type == 'pvp_challenge' ? (n.data?['gameId'] as String?) : null;
            final isGameInvitation = n.type == 'game_invitation';
            final opensElsewhere = gameId != null || isGameInvitation;
            return ListTile(
              tileColor: n.isRead ? null : AppColors.kin.withOpacity(0.05),
              leading: Icon(_iconFor(n.type), color: n.isRead ? AppColors.washiDim : AppColors.kin),
              title: Text(
                n.title,
                style: TextStyle(
                  color: AppColors.washi,
                  fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(n.body, style: TextStyle(color: AppColors.washiDim)),
              trailing: opensElsewhere
                  ? const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.kin)
                  : Text(
                      _formatDate(n.createdAt),
                      style: TextStyle(color: AppColors.washiDim, fontSize: 11),
                    ),
              onTap: gameId != null
                  ? () => _openPvpGame(context, ref, uid, n, gameId)
                  : (isGameInvitation
                      ? () => _openGameInvitations(context, ref, uid, n)
                      : (n.isRead ? null : () => _markAsRead(ref, uid, n.id))),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Notifications error: $err');
        return Center(child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)));
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'tournament_match':
        return Icons.emoji_events;
      case 'achievement':
        return Icons.star;
      case 'pvp_challenge':
        return Icons.sports_esports;
      case 'game_invitation':
        return Icons.mail_outline;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}';

  Future<void> _openPvpGame(
    BuildContext context,
    WidgetRef ref,
    String uid,
    AppNotification notification,
    String gameId,
  ) async {
    if (!notification.isRead) {
      await _markAsRead(ref, uid, notification.id);
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PvpGameScreen(gameId: gameId, uid: uid)),
      );
    }
  }

  Future<void> _openGameInvitations(
    BuildContext context,
    WidgetRef ref,
    String uid,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      await _markAsRead(ref, uid, notification.id);
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FriendsScreen(initialTabIndex: 2)),
      );
    }
  }

  Future<void> _markAsRead(WidgetRef ref, String uid, String notificationId) async {
    try {
      await ref.read(markNotificationAsReadProvider)(uid: uid, notificationId: notificationId);
      ref.invalidate(userNotificationsProvider(uid));
      ref.invalidate(unreadNotificationsProvider(uid));
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref, AppLocalizations l10n, String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.clearAllDialogTitle, style: const TextStyle(color: AppColors.washi)),
        content: Text(l10n.clearAllDialogContent, style: const TextStyle(color: AppColors.washiDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton, style: TextStyle(color: AppColors.aiLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteButton, style: TextStyle(color: AppColors.shuLight)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(clearNotificationsProvider)(uid);
        ref.invalidate(userNotificationsProvider(uid));
        ref.invalidate(unreadNotificationsProvider(uid));
      } catch (e) {
        _logger.e('Error clearing notifications: $e');
      }
    }
  }

  Future<void> _showPreferenceDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n, String uid) async {
    final preference = await ref.read(notificationPreferenceProvider(uid).future);
    if (!context.mounted) return;

    final current = preference ??
        NotificationPreference(
          uid: uid,
          friendRequests: true,
          tournamentUpdates: true,
          achievements: true,
          gameInvitations: true,
          allNotifications: true,
        );

    await showDialog(
      context: context,
      builder: (dialogContext) => _NotificationPreferenceDialog(
        preference: current,
        onSave: (updated) async {
          try {
            await ref.read(saveNotificationPreferenceProvider)(updated);
            ref.invalidate(notificationPreferenceProvider(uid));
          } catch (e) {
            _logger.e('Error saving notification preference: $e');
          }
        },
      ),
    );
  }
}

class _NotificationPreferenceDialog extends StatefulWidget {
  final NotificationPreference preference;
  final Future<void> Function(NotificationPreference) onSave;

  const _NotificationPreferenceDialog({required this.preference, required this.onSave});

  @override
  State<_NotificationPreferenceDialog> createState() => _NotificationPreferenceDialogState();
}

class _NotificationPreferenceDialogState extends State<_NotificationPreferenceDialog> {
  late bool _friendRequests;
  late bool _tournamentUpdates;
  late bool _achievements;
  late bool _gameInvitations;
  late bool _allNotifications;

  @override
  void initState() {
    super.initState();
    _friendRequests = widget.preference.friendRequests;
    _tournamentUpdates = widget.preference.tournamentUpdates;
    _achievements = widget.preference.achievements;
    _gameInvitations = widget.preference.gameInvitations;
    _allNotifications = widget.preference.allNotifications;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.sumiSurface,
      title: Text(l10n.notificationSettingsTooltip, style: const TextStyle(color: AppColors.washi)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSwitch(l10n.allNotificationsLabel, _allNotifications, (v) => setState(() => _allNotifications = v)),
            _buildSwitch(l10n.friendRequestsLabel, _friendRequests, (v) => setState(() => _friendRequests = v)),
            _buildSwitch(l10n.tournamentUpdatesLabel, _tournamentUpdates, (v) => setState(() => _tournamentUpdates = v)),
            _buildSwitch(l10n.achievementsLabel, _achievements, (v) => setState(() => _achievements = v)),
            _buildSwitch(l10n.gameInvitationsLabel, _gameInvitations, (v) => setState(() => _gameInvitations = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelButton, style: TextStyle(color: AppColors.aiLight)),
        ),
        TextButton(
          onPressed: () async {
            await widget.onSave(NotificationPreference(
              uid: widget.preference.uid,
              friendRequests: _friendRequests,
              tournamentUpdates: _tournamentUpdates,
              achievements: _achievements,
              gameInvitations: _gameInvitations,
              allNotifications: _allNotifications,
            ));
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.saveButton, style: TextStyle(color: AppColors.kin)),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: AppColors.washi)),
      value: value,
      activeColor: AppColors.kin,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}

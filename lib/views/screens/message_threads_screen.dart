import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'chat_screen.dart';

/// メッセージスレッド一覧（受信箱）。フレンド一覧の「メッセージ」から
/// 既存/新規の会話に入る方式を主としているため、ここに新規会話を開始する
/// ボタンは置いていない（フレンドでない相手とのDMはそもそも想定外）。
class MessageThreadsScreen extends ConsumerWidget {
  const MessageThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.messagesTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: currentUser == null
          ? Center(child: Text(l10n.loginRequiredMessage))
          : _buildThreadList(context, ref, l10n, currentUser),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    User currentUser,
  ) {
    final threadsAsync = ref.watch(messageThreadsProvider(currentUser.uid));

    return threadsAsync.when(
      data: (threads) {
        if (threads.isEmpty) {
          return Center(
            child: Text(
              l10n.noConversationsYetMessage,
              style: const TextStyle(color: AppColors.washiDim),
            ),
          );
        }

        return ListView.separated(
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.sumiLine, height: 1),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final otherUid = thread.otherUidFor(currentUser.uid);
            final otherName = thread.otherDisplayNameFor(currentUser.uid);
            final unread = thread.unreadCountFor(currentUser.uid);

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.kin,
                child: const Icon(Icons.person, color: AppColors.washi),
              ),
              title: Text(otherName, style: const TextStyle(color: AppColors.washi)),
              subtitle: Text(
                thread.lastMessage ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.washiDim),
              ),
              trailing: unread > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.washi,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                if (otherUid.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      currentUid: currentUser.uid,
                      currentDisplayName: currentUser.displayName ?? l10n.homeDefaultPlayerName,
                      friendUid: otherUid,
                      friendDisplayName: otherName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.couldNotLoadMessagesMessage,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

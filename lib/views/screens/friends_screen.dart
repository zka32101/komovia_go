import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../models/index.dart';
import '../../viewmodels/index.dart';
import 'package:komovia_core/komovia_core.dart';
import '../widgets/index.dart';
import 'friend_profile_screen.dart';
import 'chat_screen.dart';
import 'pvp_game_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// Friends management screen
class FriendsScreen extends ConsumerStatefulWidget {
  /// Which tab to open on ('対局の招待' notification taps land on tab 2).
  final int initialTabIndex;

  const FriendsScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // currentUserProvider is a plain Provider<User?> (not an AsyncValue).
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.friendsTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.friendsTitle),
            Tab(text: l10n.pendingTab),
            Tab(text: l10n.gameInvitationsTab),
            Tab(text: l10n.blockedTab),
          ],
        ),
      ),
      body: currentUser == null
          ? Center(child: Text(l10n.loginRequiredMessage))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(l10n, currentUser.uid),
                _buildPendingRequests(l10n, currentUser.uid),
                _buildGameInvitations(l10n, currentUser.uid),
                _buildBlockedUsers(l10n, currentUser.uid),
              ],
            ),
      floatingActionButton: currentUser == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showSearchDialog(context, l10n),
              backgroundColor: AppColors.kin,
              child: const Icon(Icons.person_add),
            ),
    );
  }

  Widget _buildFriendsList(AppLocalizations l10n, String uid) {
    final friendsAsync = ref.watch(friendsStreamProvider(uid));

    return friendsAsync.when(
      data: (friends) {
        return FriendListWidget(
          friends: friends,
          isLoading: false,
          onRefresh: () async {
            // Trigger refresh via Riverpod
            ref.refresh(friendsStreamProvider(uid));
          },
          onTap: (friend) {
            _openFriendProfile(context, uid, friend);
          },
          onMessage: (friend) {
            _openChat(context, uid, friend);
          },
          onInvite: (friend) {
            _showGameInviteDialog(context, l10n, uid, friend.friendUid, friend.displayName);
          },
          onBlock: (friend) {
            _blockFriend(context, l10n, uid, friend.friendUid);
          },
        );
      },
      loading: () => const FriendListWidget(
        friends: [],
        isLoading: true,
      ),
      error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
    );
  }

  Widget _buildPendingRequests(AppLocalizations l10n, String uid) {
    final pendingAsync = ref.watch(pendingFriendRequestsProvider(uid));

    return pendingAsync.when(
      data: (pending) {
        if (pending.isEmpty) {
          return Center(
            child: Text(l10n.noPendingRequestsMessage,
                style: TextStyle(color: AppColors.washiDim)),
          );
        }

        return ListView.builder(
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final request = pending[index];
            return _buildPendingRequestTile(context, l10n, uid, request);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
    );
  }

  Widget _buildPendingRequestTile(
    BuildContext context,
    AppLocalizations l10n,
    String uid,
    Friendship request,
  ) {
    // requestedBy is null for relationship docs created before this field
    // existed - treated as incoming (the pre-existing behavior: both
    // accept and decline shown) since there's no way to know direction.
    final isIncoming = request.requestedBy != uid;

    return Card(
      color: AppColors.kin.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.kin,
              radius: 24,
              child: const Icon(Icons.person, color: AppColors.washi),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayName,
                    style: const TextStyle(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isIncoming ? l10n.requestPendingLabel : l10n.requestSentLabel,
                    style: TextStyle(color: AppColors.kin, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isIncoming) ...[
              ElevatedButton.icon(
                onPressed: () =>
                    _acceptFriendRequest(context, l10n, uid, request.friendUid),
                icon: const Icon(Icons.check),
                label: Text(l10n.acceptButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.wakatake,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _rejectFriendRequest(context, l10n, uid, request.friendUid),
                icon: const Icon(Icons.close),
                label: Text(l10n.declineButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.shuLight,
                ),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () =>
                    _rejectFriendRequest(context, l10n, uid, request.friendUid),
                icon: const Icon(Icons.close),
                label: Text(l10n.cancelButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.washiDim,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameInvitations(AppLocalizations l10n, String uid) {
    final invitationsAsync = ref.watch(incomingInvitationsStreamProvider(uid));

    return invitationsAsync.when(
      data: (invitations) {
        if (invitations.isEmpty) {
          return Center(
            child: Text(l10n.noGameInvitationsMessage,
                style: TextStyle(color: AppColors.washiDim)),
          );
        }

        return ListView.builder(
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            return _buildGameInvitationTile(context, l10n, invitations[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
    );
  }

  Widget _buildGameInvitationTile(
    BuildContext context,
    AppLocalizations l10n,
    GameInvitation invitation,
  ) {
    return Card(
      color: AppColors.kin.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.kin,
              radius: 24,
              child: const Icon(Icons.sports_esports, color: AppColors.washi),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invitation.fromDisplayName,
                    style: const TextStyle(
                      color: AppColors.washi,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    l10n.boardSizeInviteLabel(invitation.boardSize),
                    style: TextStyle(color: AppColors.kin, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _acceptGameInvitation(context, l10n, invitation),
              icon: const Icon(Icons.check),
              label: Text(l10n.acceptButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.wakatake,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _declineGameInvitation(context, invitation),
              icon: const Icon(Icons.close),
              label: Text(l10n.declineButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.shuLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptGameInvitation(
    BuildContext context,
    AppLocalizations l10n,
    GameInvitation invitation,
  ) async {
    try {
      final game = await ref.read(acceptGameInvitationProvider)(invitation);
      if (!context.mounted) return;

      if (game == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationNoLongerAvailableMessage)),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PvpGameScreen(gameId: game.id, uid: invitation.toUid),
        ),
      );
    } catch (e) {
      _logger.e('Error accepting game invitation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invitationAcceptFailedMessage)),
        );
      }
    }
  }

  Future<void> _declineGameInvitation(BuildContext context, GameInvitation invitation) async {
    try {
      await ref.read(declineGameInvitationProvider)(invitation.id);
    } catch (e) {
      _logger.e('Error declining game invitation: $e');
    }
  }

  Widget _buildBlockedUsers(AppLocalizations l10n, String uid) {
    final blockedFuture = ref.watch(blockedFriendsProvider(uid));

    return blockedFuture.when(
      data: (blocked) {
        if (blocked.isEmpty) {
          return Center(
            child: Text(l10n.noBlockedUsersMessage,
                style: TextStyle(color: AppColors.washiDim)),
          );
        }

        return ListView.builder(
          itemCount: blocked.length,
          itemBuilder: (context, index) {
            final user = blocked[index];
            return Card(
              color: AppColors.sumiSurface,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.shuLight,
                      radius: 24,
                      child: const Icon(Icons.person, color: AppColors.washi),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          _unblockUser(context, l10n, uid, user.uid),
                      child: Text(l10n.unblockButton),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.washiDim,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(l10n.errorPrefix('$err'))),
    );
  }

  void _showSearchDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => _FriendSearchDialog(
        l10n: l10n,
        onSearch: (query) {
          // dialogContextはこのダイアログ自身のルートに属しており、
          // Navigator.popで閉じ始めた直後にそれを使ってshowModalBottomSheet
          // を呼ぶと（popされつつあるルートのcontextなので）シートが実際には
          // 表示されない。結果ボトムシートはFriendsScreen自身の（長生きする）
          // contextに紐付ける。
          Navigator.pop(dialogContext);
          _searchFriends(context, l10n, query);
        },
      ),
    );
  }

  void _searchFriends(BuildContext context, AppLocalizations l10n, String query) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    final uid = currentUser.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sumiSurface,
      builder: (sheetContext) {
        // Consumerでラップしないと、ref.watch()の購読先がこのシート自身
        // ではなくFriendsScreen自身のElementに紐付いてしまう
        // （showModalBottomSheetのbuilderはFriendsScreenのbuild()とは
        // 別のツリーで、しかも一度しか呼ばれない）。その結果、
        // searchUsersProvider/friendStatusProviderが後から解決しても
        // このシートは再ビルドされず、ローディング表示のまま固まって
        // 検索結果が永遠に表示されない。
        return Consumer(
          builder: (context, ref, child) {
            final resultsAsync = ref.watch(searchUsersProvider(query));

            return resultsAsync.when(
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Text(l10n.noUsersFoundMessage,
                        style: TextStyle(color: AppColors.washiDim)),
                  );
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final user = results[index];
                    return ListTile(
                      title: Text(user.displayName,
                          style: const TextStyle(color: AppColors.washi)),
                      subtitle: Text(l10n.gamesCountLabel(user.totalGamesPlayed),
                          style: TextStyle(color: AppColors.washiDim)),
                      trailing: _buildAddFriendAction(context, ref, l10n, uid, user.uid),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text(l10n.errorPrefix('$err'))),
            );
          },
        );
      },
    );
  }

  /// フレンド候補の既存関係の状態に応じて表示を変える。すでにaccepted/
  /// blockedの相手に「追加」を出すと、再タップでFriendService.addFriendの
  /// ガードに引っかかり無反応に見えるだけで終わってしまうため、状態を
  /// 見て事前にラベルを変えておく（ガード自体はサービス層にもあるので
  /// 二重の安全策）。
  Widget _buildAddFriendAction(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String uid,
    String targetUid,
  ) {
    final statusAsync = ref.watch(friendStatusProvider((uid, targetUid)));

    return statusAsync.when(
      data: (status) {
        switch (status) {
          case 'accepted':
            return Text(l10n.friendsTitle, style: TextStyle(color: AppColors.washiDim));
          case 'pending':
            return Text(l10n.pendingStatusLabel, style: TextStyle(color: AppColors.washiDim));
          case 'blocked':
            return Text(l10n.blockedTab, style: TextStyle(color: AppColors.washiDim));
          default:
            return ElevatedButton(
              onPressed: () => _addFriend(context, l10n, targetUid),
              child: Text(l10n.addButton),
            );
        }
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (err, stack) => ElevatedButton(
        onPressed: () => _addFriend(context, l10n, targetUid),
        child: Text(l10n.addButton),
      ),
    );
  }

  void _handleFriendAction(
    BuildContext context,
    AppLocalizations l10n,
    String uid,
    Friendship friend,
    String action,
  ) {
    switch (action) {
      case 'message':
        _openChat(context, uid, friend);
        break;
      case 'invite':
        _showGameInviteDialog(context, l10n, uid, friend.friendUid, friend.displayName);
        break;
      case 'profile':
        _openFriendProfile(context, uid, friend);
        break;
      case 'block':
        _blockFriend(context, l10n, uid, friend.friendUid);
        break;
    }
  }

  void _addFriend(BuildContext context, AppLocalizations l10n, String friendUid) async {
    // currentUserProvider is a plain Provider<User?> (not an AsyncValue).
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final fromDisplayName = currentUser.displayName ?? l10n.homeDefaultPlayerName;
    final success = await ref.read(
      addFriendProvider((currentUser.uid, friendUid, fromDisplayName, null)).future,
    );

    if (success) {
      ref.invalidate(friendStatusProvider((currentUser.uid, friendUid)));
    }
    if (!mounted) return;
    _showMessage(context, success ? l10n.friendRequestSentMessage : l10n.genericErrorMessage);
    if (success) Navigator.pop(context);
  }

  void _acceptFriendRequest(
    BuildContext context,
    AppLocalizations l10n,
    String uid,
    String friendUid,
  ) async {
    final success = await ref.read(
      acceptFriendRequestProvider((uid, friendUid)).future,
    );

    if (!mounted) return;
    _showMessage(context, success ? l10n.becameFriendsMessage : l10n.genericErrorMessage);
  }

  void _blockFriend(BuildContext context, AppLocalizations l10n, String uid, String friendUid) async {
    final success = await ref.read(
      blockFriendProvider((uid, friendUid)).future,
    );

    if (success) {
      ref.invalidate(blockedFriendsProvider(uid));
      ref.invalidate(pendingFriendRequestsProvider(uid));
    }
    if (!mounted) return;
    _showMessage(context, success ? l10n.blockedMessage : l10n.genericErrorMessage);
  }

  /// Declines an incoming request or cancels one the current user sent -
  /// both are the same "delete the pending request" operation, just
  /// triggered from different sides (see FriendService.rejectFriendRequest).
  void _rejectFriendRequest(
    BuildContext context,
    AppLocalizations l10n,
    String uid,
    String friendUid,
  ) async {
    final success = await ref.read(
      rejectFriendRequestProvider((uid, friendUid)).future,
    );

    if (success) {
      ref.invalidate(pendingFriendRequestsProvider(uid));
    }
    if (!mounted) return;
    _showMessage(
      context,
      success ? l10n.friendRequestRemovedMessage : l10n.genericErrorMessage,
    );
  }

  void _unblockUser(BuildContext context, AppLocalizations l10n, String uid, String friendUid) async {
    final success = await ref.read(
      unblockFriendProvider((uid, friendUid)).future,
    );

    if (success) {
      ref.invalidate(blockedFriendsProvider(uid));
    }
    if (!mounted) return;
    _showMessage(context, success ? l10n.unblockedMessage : l10n.genericErrorMessage);
  }

  void _showGameInviteDialog(
    BuildContext context,
    AppLocalizations l10n,
    String fromUid,
    String toUid,
    String displayName,
  ) {
    int selectedBoardSize = 19;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: AppColors.sumiSurface,
          title: Text(l10n.inviteToGameDialogTitle(displayName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.selectGameModeMessage, style: TextStyle(color: AppColors.washiDim)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [9, 13, 19].map((size) {
                  return ChoiceChip(
                    label: Text('$size × $size'),
                    selected: selectedBoardSize == size,
                    onSelected: (_) => setState(() => selectedBoardSize = size),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancelButton),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _sendGameInvitation(
                  context,
                  l10n,
                  fromUid,
                  toUid,
                  displayName,
                  selectedBoardSize,
                );
              },
              child: Text(l10n.sendInvitationButton),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendGameInvitation(
    BuildContext context,
    AppLocalizations l10n,
    String fromUid,
    String toUid,
    String toDisplayName,
    int boardSize,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    final fromDisplayName = currentUser?.displayName ?? l10n.homeDefaultPlayerName;

    final success = await ref.read(sendGameInvitationProvider)(
      fromUid: fromUid,
      fromDisplayName: fromDisplayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      boardSize: boardSize,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.invitationSentMessage : l10n.genericErrorMessage,
        ),
      ),
    );
  }

  void _openFriendProfile(BuildContext context, String uid, Friendship friend) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          currentUid: uid,
          friend: friend,
          onInvite: () => _showGameInviteDialog(context, l10n, uid, friend.friendUid, friend.displayName),
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String uid, Friendship friend) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    final currentDisplayName = currentUser?.displayName ?? l10n.homeDefaultPlayerName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUid: uid,
          currentDisplayName: currentDisplayName,
          friendUid: friend.friendUid,
          friendDisplayName: friend.displayName,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Friend search dialog
class _FriendSearchDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final Function(String) onSearch;

  const _FriendSearchDialog({required this.l10n, required this.onSearch});

  @override
  State<_FriendSearchDialog> createState() => _FriendSearchDialogState();
}

class _FriendSearchDialogState extends State<_FriendSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      backgroundColor: AppColors.sumiSurface,
      title: Text(l10n.searchFriendsDialogTitle),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: l10n.usernameHint,
          hintStyle: TextStyle(color: AppColors.washiDim),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.kin),
          ),
        ),
        style: const TextStyle(color: AppColors.washi),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelButton),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              widget.onSearch(_controller.text);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.kin),
          child: Text(l10n.searchButton),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/extended_game_models.dart';
import 'package:komovia_go/config/theme.dart';

/// Widget for displaying a list of friends
class FriendListWidget extends StatelessWidget {
  final List<Friend> friends;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Function(Friend)? onTap;
  final Function(Friend)? onMessage;
  final Function(Friend)? onInvite;
  final Function(Friend)? onBlock;

  const FriendListWidget({
    Key? key,
    required this.friends,
    this.isLoading = false,
    this.onRefresh,
    this.onTap,
    this.onMessage,
    this.onInvite,
    this.onBlock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 48, color: AppColors.washiDim),
            const SizedBox(height: 16),
            Text(
              'フレンドがいません',
              style: TextStyle(
                color: AppColors.washiDim,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      backgroundColor: AppColors.sumiSurface,
      color: AppColors.kin,
      child: ListView.separated(
        itemCount: friends.length,
        separatorBuilder: (context, index) =>
            Divider(color: AppColors.sumiCard, height: 1),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _FriendListItem(
            friend: friend,
            onTap: onTap,
            onMessage: onMessage,
            onInvite: onInvite,
            onBlock: onBlock,
          );
        },
      ),
    );
  }
}

/// Individual friend list item widget
class _FriendListItem extends StatelessWidget {
  final Friend friend;
  final Function(Friend)? onTap;
  final Function(Friend)? onMessage;
  final Function(Friend)? onInvite;
  final Function(Friend)? onBlock;

  const _FriendListItem({
    Key? key,
    required this.friend,
    this.onTap,
    this.onMessage,
    this.onInvite,
    this.onBlock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(friend),
      child: Container(
        color: AppColors.sumiSurface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.kin.withOpacity(0.2),
                  border: Border.all(color: AppColors.kin, width: 2),
                ),
                child: Center(
                  child: Text(
                    _getInitials(friend.displayName),
                    style: TextStyle(
                      color: AppColors.kin,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Friend info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (friend.notes != null && friend.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          friend.notes!,
                          style: TextStyle(
                            color: AppColors.washiDim,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'message':
                      onMessage?.call(friend);
                      break;
                    case 'invite':
                      onInvite?.call(friend);
                      break;
                    case 'block':
                      onBlock?.call(friend);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'message',
                    child: Row(
                      children: [
                        Icon(Icons.mail_outline,
                            size: 18, color: AppColors.washiDim),
                        const SizedBox(width: 12),
                        const Text('メッセージ'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.sports_esports,
                            size: 18, color: AppColors.kin),
                        const SizedBox(width: 12),
                        const Text('対局招待'),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, size: 18, color: AppColors.shuLight),
                        const SizedBox(width: 12),
                        Text('ブロック',
                            style: TextStyle(color: AppColors.shuLight)),
                      ],
                    ),
                  ),
                ],
                color: AppColors.washiDim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    return name
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0])
        .take(2)
        .join()
        .toUpperCase();
  }
}

/// Compact friend chip for display in other contexts
class FriendChipWidget extends StatelessWidget {
  final Friend friend;
  final VoidCallback? onTap;

  const FriendChipWidget({
    Key? key,
    required this.friend,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.washiDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.washiDim),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small avatar
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.kin.withOpacity(0.3),
              ),
              child: Center(
                child: Text(
                  _getInitials(friend.displayName),
                  style: TextStyle(
                    color: AppColors.kin,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Name
            Text(
              friend.displayName,
              style: const TextStyle(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),

          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    return name
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0])
        .take(2)
        .join()
        .toUpperCase();
  }
}

/// Horizontal scrollable friends list for quick selection
class FriendHorizontalListWidget extends StatelessWidget {
  final List<Friend> friends;
  final Function(Friend)? onFriendSelected;

  const FriendHorizontalListWidget({
    Key? key,
    required this.friends,
    this.onFriendSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'フレンドなし',
            style: TextStyle(color: AppColors.washiDim),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: friends.map((friend) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => onFriendSelected?.call(friend),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.kin.withOpacity(0.2),
                      border: Border.all(
                        color: AppColors.kin,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(friend.displayName),
                        style: TextStyle(
                          color: AppColors.kin,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      friend.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.washi,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getInitials(String name) {
    return name
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0])
        .take(2)
        .join()
        .toUpperCase();
  }
}

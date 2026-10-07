import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/go_rank.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// フレンドの読み取り専用プロフィール画面。フレンド一覧からの遷移のみを
/// 想定しているため、Friendオブジェクトをそのまま受け取る（名前付きルート
/// は使わない — 通知やディープリンクからこの画面へ直接遷移する経路が無い）。
class FriendProfileScreen extends ConsumerStatefulWidget {
  final String currentUid;
  final Friend friend;
  final VoidCallback? onInvite;

  const FriendProfileScreen({
    Key? key,
    required this.currentUid,
    required this.friend,
    this.onInvite,
  }) : super(key: key);

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _isCalculatingEnScore = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final friend = widget.friend;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(friend.displayName),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(l10n, friend),
          const SizedBox(height: 24),
          _buildRankCard(l10n, friend.uid),
          const SizedBox(height: 16),
          _buildEnScoreCard(l10n, friend),
          if (friend.notes != null && friend.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(l10n, friend.notes!),
          ],
          if (widget.onInvite != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onInvite,
                icon: const Icon(Icons.sports_esports),
                label: Text(l10n.inviteToGameButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kin,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, Friend friend) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.kin,
          backgroundImage: friend.avatarUrl != null
              ? NetworkImage(friend.avatarUrl!)
              : null,
          child: friend.avatarUrl == null
              ? const Icon(Icons.person, color: AppColors.washi, size: 40)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          friend.displayName,
          style: const TextStyle(
            color: AppColors.washi,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.friendshipDurationLabel(_formatFriendshipDuration(l10n, friend.addedAt)),
          style: TextStyle(color: AppColors.washiDim, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRankCard(AppLocalizations l10n, String friendUid) {
    final rankAsync = ref.watch(userLeaderboardRankProvider(
      (uid: friendUid, period: LeaderboardPeriod.allTime, type: LeaderboardType.rating),
    ));

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: rankAsync.when(
          data: (entry) {
            final rating = entry?.rating ?? 1200;
            return Row(
              children: [
                const Icon(Icons.military_tech, color: AppColors.kin),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatGoRank(rating),
                        style: const TextStyle(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.ratingLabel(rating),
                        style: TextStyle(color: AppColors.washiDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, stack) => Text(l10n.rankFetchFailedMessage, style: TextStyle(color: AppColors.washiDim)),
        ),
      ),
    );
  }

  Widget _buildEnScoreCard(AppLocalizations l10n, Friend friend) {
    final connectionAsync = ref.watch(
      enConnectionProvider((uid: widget.currentUid, friendUid: friend.uid)),
    );

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: connectionAsync.when(
          data: (connection) {
            if (connection == null) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.enScoreNotCalculatedMessage,
                      style: TextStyle(color: AppColors.washiDim),
                    ),
                  ),
                  TextButton(
                    onPressed: _isCalculatingEnScore ? null : () => _calculateEnScore(l10n, friend),
                    child: _isCalculatingEnScore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.calculateButton),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      connection.level,
                      style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: _isCalculatingEnScore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18, color: AppColors.washiDim),
                      onPressed: _isCalculatingEnScore ? null : () => _calculateEnScore(l10n, friend),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: connection.score / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.sumiCard,
                    valueColor: const AlwaysStoppedAnimation(Colors.pinkAccent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.enScoreLabel(connection.score, connection.matchesPlayed),
                  style: TextStyle(color: AppColors.washiDim, fontSize: 12),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, stack) => Text(l10n.enScoreFetchFailedMessage, style: TextStyle(color: AppColors.washiDim)),
        ),
      ),
    );
  }

  Widget _buildNotesCard(AppLocalizations l10n, String notes) {
    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.notesLabel, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
            const SizedBox(height: 4),
            Text(notes, style: const TextStyle(color: AppColors.washi)),
          ],
        ),
      ),
    );
  }

  Future<void> _calculateEnScore(AppLocalizations l10n, Friend friend) async {
    setState(() => _isCalculatingEnScore = true);
    try {
      await ref.read(calculateEnScoreProvider)(
        widget.currentUid,
        friend.uid,
        friend.displayName,
        friend.addedAt,
      );
      ref.invalidate(enConnectionProvider((uid: widget.currentUid, friendUid: friend.uid)));
    } catch (e) {
      _logger.e('Failed to calculate en score: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.enScoreCalculateFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingEnScore = false);
    }
  }

  String _formatFriendshipDuration(AppLocalizations l10n, DateTime addedAt) {
    final days = DateTime.now().difference(addedAt).inDays;
    if (days < 1) return l10n.friendshipSinceTodayLabel;
    if (days < 30) return l10n.friendshipDaysLabel(days);
    if (days < 365) return l10n.friendshipMonthsLabel((days / 30).floor());
    return l10n.friendshipYearsLabel((days / 365).floor());
  }
}

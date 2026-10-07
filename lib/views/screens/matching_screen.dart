import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/utils/go_rank.dart';
import 'pvp_game_screen.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 実力マッチングEngine画面 - レートの近い相手との「運命の対戦」
class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  int _boardSize = 19;
  bool _isSearching = false;
  bool _isStartingGame = false;
  MatchResult? _foundMatch;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.matchingTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.matchingIntro,
                    style: TextStyle(color: AppColors.washiDim),
                  ),
                  const SizedBox(height: 8),
                  _buildMyRank(l10n, uid),
                  const SizedBox(height: 16),
                  _buildBoardSizeSelector(),
                  const SizedBox(height: 20),
                  if (_foundMatch != null) _buildMatchFoundCard(l10n, _foundMatch!, uid, currentUser!),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : () => _findMatch(l10n, uid, currentUser!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kin,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              l10n.findOpponentButton,
                              style: const TextStyle(color: AppColors.sumi, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.matchHistoryTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildMatchHistory(l10n, uid),
                ],
              ),
            ),
    );
  }

  Widget _buildMyRank(AppLocalizations l10n, String uid) {
    final rankAsync = ref.watch(userLeaderboardRankProvider(
      (uid: uid, period: LeaderboardPeriod.allTime, type: LeaderboardType.rating),
    ));
    final rating = rankAsync.valueOrNull?.rating ?? 1200;
    return Text(
      l10n.myRankLabel(formatGoRank(rating), rating),
      style: const TextStyle(color: AppColors.kin, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildBoardSizeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [9, 13, 19].map((size) {
        final selected = _boardSize == size;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(l10n.boardSizePathLabel(size)),
            selected: selected,
            onSelected: (_) => setState(() => _boardSize = size),
            selectedColor: AppColors.kin,
            backgroundColor: AppColors.sumiCard,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchFoundCard(AppLocalizations l10n, MatchResult match, String uid, User currentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.kin, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.kin.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake, color: AppColors.kin),
              const SizedBox(width: 8),
              Text(
                l10n.matchFoundTitle,
                style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${match.player1DisplayName} (${formatGoRank(match.player1Rating)}) vs '
            '${match.player2DisplayName} (${formatGoRank(match.player2Rating)})',
            style: const TextStyle(color: AppColors.washiDim),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ratingDiffLabel(match.ratingDiff, match.boardSize),
            style: TextStyle(color: AppColors.washiDim, fontSize: 12),
          ),
          if (match.gameId == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isStartingGame ? null : () => _startGame(l10n, match, uid, currentUser),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.wakatake),
                child: _isStartingGame
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.washi),
                      )
                    : Text(l10n.startGameButton, style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchHistory(AppLocalizations l10n, String uid) {
    final historyAsync = ref.watch(matchHistoryProvider(uid));
    return historyAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return Text(l10n.noMatchHistoryMessage, style: TextStyle(color: AppColors.washiDim));
        }
        return Column(
          children: matches.map((match) {
            final isPlayer1 = match.player1Uid == uid;
            final opponentName = isPlayer1 ? match.player2DisplayName : match.player1DisplayName;
            final opponentRating = isPlayer1 ? match.player2Rating : match.player1Rating;
            return Card(
              color: AppColors.sumiSurface,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person, color: AppColors.washiDim),
                title: Text(opponentName, style: const TextStyle(color: AppColors.washi)),
                subtitle: Text(
                  l10n.ratingBoardSizeLabel(opponentRating, match.boardSize),
                  style: TextStyle(color: AppColors.washiDim),
                ),
                trailing: match.gameId != null
                    ? const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16)
                    : null,
                onTap: match.gameId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PvpGameScreen(gameId: match.gameId!, uid: uid),
                          ),
                        ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Match history error: $err');
        return Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent));
      },
    );
  }

  Future<void> _findMatch(AppLocalizations l10n, String uid, User currentUser) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final rankEntry = await ref.read(userLeaderboardRankProvider(
        (uid: uid, period: LeaderboardPeriod.allTime, type: LeaderboardType.rating),
      ).future);
      final rating = rankEntry?.rating ?? 1200;
      final displayName = currentUser.displayName ?? 'Player';

      await ref.read(joinMatchmakingQueueProvider)(uid, displayName, rating, _boardSize);
      final match = await ref.read(findMatchProvider)(uid, displayName, rating, _boardSize);

      if (!mounted) return;
      setState(() {
        _foundMatch = match;
        _error = match == null ? l10n.noMatchFoundMessage : null;
      });

      if (match != null) {
        ref.invalidate(matchHistoryProvider(uid));
      }
    } catch (e) {
      _logger.e('Error finding match: $e');
      if (mounted) {
        setState(() => _error = l10n.errorPrefix('$e'));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _startGame(AppLocalizations l10n, MatchResult match, String uid, User currentUser) async {
    setState(() => _isStartingGame = true);
    try {
      final isPlayer1 = match.player1Uid == uid;
      final opponentUid = isPlayer1 ? match.player2Uid : match.player1Uid;
      final opponentName = isPlayer1 ? match.player2DisplayName : match.player1DisplayName;
      final myName = currentUser.displayName ?? 'Player';

      // マッチを見つけた側が黒番（先手）を持つ。
      final game = await ref.read(createPvpGameProvider)(
        match.boardSize,
        uid,
        myName,
        opponentUid,
        opponentName,
        matchId: match.id,
      );

      await ref.read(attachGameToMatchProvider)(match.id, game.id);

      try {
        await ref.read(sendNotificationProvider)(
          uid: opponentUid,
          title: l10n.opponentGameStartedNotifTitle(myName),
          body: l10n.opponentGameStartedNotifBody,
          type: 'pvp_challenge',
          data: {'gameId': game.id},
        );
      } catch (e) {
        _logger.w('Failed to notify opponent of new PvP game (non-fatal): $e');
      }

      if (!mounted) return;
      ref.invalidate(matchHistoryProvider(uid));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PvpGameScreen(gameId: game.id, uid: uid)),
      );
    } catch (e) {
      _logger.e('Error starting PvP game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gameStartFailedMessage('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingGame = false);
      }
    }
  }
}

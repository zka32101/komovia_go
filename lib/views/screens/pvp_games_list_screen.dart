import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/services/pvp_game_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'pvp_game_screen.dart';

final _logger = Logger();

/// 進行中のPvP対局一覧。マッチングやトーナメントから対局を始めた後、
/// 通知やマッチ履歴を経由せず直接戻ってこられる専用画面
/// （`userActivePvpGamesProvider`はPhase 58から用意されていたが、
/// これまで専用の一覧画面が無かった）。
class PvpGamesListScreen extends ConsumerWidget {
  const PvpGamesListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.homePvpGamesTitle),
        backgroundColor: AppColors.sumi,
        elevation: 0,
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.loginRequiredMessage,
                style: TextStyle(color: AppColors.washiDim),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userActivePvpGamesProvider(uid));
                await ref.read(userActivePvpGamesProvider(uid).future);
              },
              child: _buildGamesList(context, l10n, ref, uid),
            ),
    );
  }

  Widget _buildGamesList(BuildContext context, AppLocalizations l10n, WidgetRef ref, String uid) {
    final gamesAsync = ref.watch(userActivePvpGamesProvider(uid));

    return gamesAsync.when(
      data: (games) {
        if (games.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              Center(
                child: Text(
                  l10n.noActivePvpGamesMessage,
                  style: TextStyle(color: AppColors.washiDim),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: games.length,
          itemBuilder: (context, index) {
            return _buildGameCard(context, ref, l10n, games[index], uid);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Error loading active PvP games: $err');
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.errorPrefix('$err'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PvpGame game,
    String uid,
  ) {
    final isBlack = game.playerColorOf(uid) == 1;
    final opponentName = isBlack ? game.whiteDisplayName : game.blackDisplayName;
    final myTurn = game.isTurnOf(uid);
    final canClaimForfeit = game.canClaimAbandonmentForfeit(
      uid,
      threshold: PvpGameService.abandonmentThreshold,
    );

    return Card(
      color: AppColors.sumiSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: (myTurn ? AppColors.kin : AppColors.washiDim).withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: myTurn ? AppColors.kin : AppColors.washiDim,
              ),
            ),
            title: Text(
              l10n.vsOpponentLabel(opponentName),
              style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${l10n.boardMovesLabel(game.boardSize, game.movesCount)} · ${isBlack ? l10n.blackTurnLabel : l10n.whiteTurnLabel}'
              '${canClaimForfeit ? '\n${l10n.opponentInactiveMessage}' : ''}',
              style: TextStyle(color: canClaimForfeit ? AppColors.shuLight : AppColors.washiDim),
            ),
            isThreeLine: canClaimForfeit,
            trailing: myTurn
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.kin,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.yourTurnLabel,
                      style: const TextStyle(color: AppColors.sumi, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
                : Text(l10n.opponentTurnLabel, style: TextStyle(color: AppColors.washiDim, fontSize: 12)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PvpGameScreen(gameId: game.id, uid: uid),
              ),
            ),
          ),
          if (canClaimForfeit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.shuLight),
                  onPressed: () => _confirmClaimForfeit(context, ref, l10n, game, uid),
                  child: Text(l10n.claimForfeitButton),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClaimForfeit(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PvpGame game,
    String uid,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sumiSurface,
        title: Text(l10n.claimForfeitConfirmTitle, style: const TextStyle(color: AppColors.washi)),
        content: Text(l10n.claimForfeitConfirmContent, style: TextStyle(color: AppColors.washiDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancelButton, style: TextStyle(color: AppColors.aiLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.claimForfeitButton, style: TextStyle(color: AppColors.shuLight)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(claimAbandonmentForfeitProvider)(game.id, uid);
    } catch (e) {
      _logger.e('Error claiming forfeit: $e');
    }
  }
}

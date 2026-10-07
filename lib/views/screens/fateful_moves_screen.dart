import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/models/index.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 運命の一手画面 - 対局中に検出された劇的な瞬間の記録
class FatefulMovesScreen extends ConsumerWidget {
  const FatefulMovesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.fatefulMovesCardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : _buildMovesList(l10n, ref, uid),
    );
  }

  Widget _buildMovesList(AppLocalizations l10n, WidgetRef ref, String uid) {
    final movesAsync = ref.watch(fatefulMovesProvider(uid));
    return movesAsync.when(
      data: (moves) {
        if (moves.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.noFatefulMovesMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.washiDim),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: moves.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final move = moves[index];
            return Card(
              color: AppColors.sumiSurface,
              child: ListTile(
                leading: Icon(_iconFor(move.type), color: Colors.orangeAccent),
                title: Text(
                  move.type.getDisplayName(),
                  style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  l10n.moveNumberStonesCapturedLabel(move.moveNumber, move.stonesCaptured),
                  style: TextStyle(color: AppColors.washiDim),
                ),
                trailing: move.sharedWithFriends
                    ? const Icon(Icons.share, color: Colors.greenAccent, size: 18)
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Fateful moves error: $err');
        return Center(
          child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)),
        );
      },
    );
  }

  IconData _iconFor(FatefulMoveType type) {
    switch (type) {
      case FatefulMoveType.bigCapture:
        return Icons.whatshot;
      case FatefulMoveType.tesuji:
        return Icons.auto_awesome;
      case FatefulMoveType.koFight:
        return Icons.sync_alt;
      case FatefulMoveType.lifeAndDeath:
        return Icons.favorite;
    }
  }
}

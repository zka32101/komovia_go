import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 同時刻の碁盤画面 - いま同じ時間に対局しているプレイヤーを可視化
class ConcurrentPlayersScreen extends ConsumerWidget {
  const ConcurrentPlayersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;
    final playersAsync = ref.watch(concurrentPlayersProvider(uid));

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.concurrentPlayersCardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(concurrentPlayersProvider(uid)),
          ),
        ],
      ),
      body: playersAsync.when(
        data: (players) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.wakatake),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.wakatake.withOpacity(0.08),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.groups, color: AppColors.wakatake, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        l10n.concurrentPlayersCountLabel(players.length),
                        style: const TextStyle(
                          color: AppColors.washi,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.notAloneMessage,
                        style: TextStyle(color: AppColors.washiDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: players.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noOneCurrentlyPlayingMessage,
                          style: TextStyle(color: AppColors.washiDim),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: players.length,
                        separatorBuilder: (_, __) => Divider(color: AppColors.washiDim),
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return ListTile(
                            leading: const Icon(Icons.circle, color: Colors.greenAccent, size: 12),
                            title: Text(player.displayName, style: const TextStyle(color: AppColors.washi)),
                            subtitle: Text(
                              l10n.gameTypeBoardSizeLabel(player.gameType, player.boardSize),
                              style: TextStyle(color: AppColors.washiDim),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          _logger.e('Concurrent players error: $err');
          return Center(
            child: Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent)),
          );
        },
      ),
    );
  }
}

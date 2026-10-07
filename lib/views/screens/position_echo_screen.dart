import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

final _logger = Logger();

/// 局面の轍画面 - 名局と同じ局面に辿り着いた記録
class PositionEchoScreen extends ConsumerWidget {
  const PositionEchoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final uid = currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.positionEchoCardTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: uid == null
          ? Center(
              child: Text(l10n.loginRequiredMessage, style: const TextStyle(color: AppColors.washiDim)),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.positionEchoIntro,
                    style: TextStyle(color: AppColors.washiDim),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildEchoList(l10n, ref, uid)),
                ],
              ),
            ),
    );
  }

  Widget _buildEchoList(AppLocalizations l10n, WidgetRef ref, String uid) {
    final echoesAsync = ref.watch(historicalEchoesProvider(uid));
    return echoesAsync.when(
      data: (echoes) {
        if (echoes.isEmpty) {
          return Center(
            child: Text(
              l10n.noEchoesMessage,
              style: TextStyle(color: AppColors.washiDim),
            ),
          );
        }
        return ListView.separated(
          itemCount: echoes.length,
          separatorBuilder: (_, __) => Divider(color: AppColors.washiDim),
          itemBuilder: (context, index) {
            final echo = echoes[index];
            return ListTile(
              leading: const Icon(Icons.history_edu, color: Colors.deepPurpleAccent),
              title: Text(
                echo.kifuTitle ?? l10n.famousGameDefaultLabel,
                style: const TextStyle(color: AppColors.washi),
              ),
              subtitle: Text(
                l10n.moveNumberBoardSizeLabel(echo.moveNumber, echo.boardSize),
                style: TextStyle(color: AppColors.washiDim),
              ),
              trailing: Text(
                _formatDate(echo.reachedAt),
                style: TextStyle(color: AppColors.washiDim, fontSize: 12),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) {
        _logger.e('Position echo error: $err');
        return Text(l10n.errorPrefix('$err'), style: const TextStyle(color: Colors.redAccent));
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}

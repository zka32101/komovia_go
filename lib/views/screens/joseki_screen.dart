import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';

/// 戦法（定石）ライブラリ - 代表的な隅の定石を、手順と狙いの解説付きで紹介する。
/// 対局のインポートやリプレイは行わず、静的な参考資料として提供する。
class JosekiScreen extends StatelessWidget {
  const JosekiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final josekis = <_Joseki>[
      _Joseki(name: l10n.joseki1Name, moves: l10n.joseki1Moves, idea: l10n.joseki1Idea),
      _Joseki(name: l10n.joseki2Name, moves: l10n.joseki2Moves, idea: l10n.joseki2Idea),
      _Joseki(name: l10n.joseki3Name, moves: l10n.joseki3Moves, idea: l10n.joseki3Idea),
      _Joseki(name: l10n.joseki4Name, moves: l10n.joseki4Moves, idea: l10n.joseki4Idea),
      _Joseki(name: l10n.joseki5Name, moves: l10n.joseki5Moves, idea: l10n.joseki5Idea),
    ];

    return Scaffold(
      backgroundColor: AppColors.sumi,
      appBar: AppBar(
        title: Text(l10n.homeJosekiTitle),
        backgroundColor: AppColors.sumiSurface,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: josekis.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.josekiIntro,
                style: TextStyle(color: AppColors.washiDim, height: 1.6),
              ),
            );
          }
          return _buildJosekiCard(josekis[index - 1]);
        },
      ),
    );
  }

  Widget _buildJosekiCard(_Joseki joseki) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.sumiLine),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.washi.withOpacity(0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            joseki.name,
            style: const TextStyle(color: AppColors.washi, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            joseki.moves,
            style: TextStyle(color: AppColors.kin, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            joseki.idea,
            style: TextStyle(color: AppColors.washiDim, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Joseki {
  final String name;
  final String moves;
  final String idea;

  const _Joseki({required this.name, required this.moves, required this.idea});
}

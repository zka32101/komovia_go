import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/ai_opponent_config.dart';
import 'package:komovia_go/viewmodels/index.dart';

/// 中断中のAI対局があるとき、新規対局を始める前に上書き確認を出す。
/// 中断中の対局が無ければ確認なしで即trueを返す。
Future<bool> confirmOverwriteActiveGame(
  BuildContext context,
  WidgetRef ref,
) async {
  final activeGame = ref.read(activeAiGameProvider).valueOrNull;
  if (activeGame == null) return true;
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.newGameOverwritesActiveTitle),
      content: Text(l10n.newGameOverwritesActiveMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.newGameOverwritesActiveConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// AI対局の開始前に強さを選ばせるボトムシート。
///
/// レベル1〜[AIOpponentConfig.freeMaxLevel]は無料、それ以上は
/// プレミアム会員のみ。ロック中のレベルを押すと課金画面へ誘導する。
/// 選ばれたレベルを設定してtrueを返す（キャンセル時はfalse）。
Future<bool> showAiLevelSheet(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.sumi,
    isScrollControlled: true,
    builder: (_) => const _AiLevelSheet(),
  );
  if (picked == null) return false;
  ref.read(setAiConfigProvider)(
    AIOpponentConfig(
      level: picked,
      engineParams: {
        'level': '$picked',
        'thinking_time': '${1000 + picked * 1000}',
      },
    ),
  );
  return true;
}

class _AiLevelSheet extends ConsumerStatefulWidget {
  const _AiLevelSheet();

  @override
  ConsumerState<_AiLevelSheet> createState() => _AiLevelSheetState();
}

class _AiLevelSheetState extends ConsumerState<_AiLevelSheet> {
  // 短時間対局向けに5路・7路も選べるようにしている(2026-10 追加)。
  static const List<int> _boardSizes = [5, 7, 9, 13, 19];

  late int _selected;
  late int _selectedBoardSize;

  @override
  void initState() {
    super.initState();
    final isPremium = ref.read(isSubscriptionActiveProvider);
    final last = ref.read(aiLevelProvider);
    // 購読が切れた後に前回の高レベルが残っていても、無料枠に丸める。
    _selected = isPremium ? last : last.clamp(1, AIOpponentConfig.freeMaxLevel);
    _selectedBoardSize = ref.read(quickBoardSizeProvider);
  }

  String _boardSizeLabel(AppLocalizations l10n, int size) {
    switch (size) {
      case 5:
        return l10n.boardSizeOption5;
      case 7:
        return l10n.boardSizeOption7;
      case 13:
        return l10n.boardSizeOption13;
      case 19:
        return l10n.boardSizeOption19;
      default:
        return l10n.boardSizeOption9;
    }
  }

  String _boardSizeEstimate(AppLocalizations l10n, int size) {
    switch (size) {
      case 5:
        return l10n.boardSizeEstimate5;
      case 7:
        return l10n.boardSizeEstimate7;
      case 13:
        return l10n.boardSizeEstimate13;
      case 19:
        return l10n.boardSizeEstimate19;
      default:
        return l10n.boardSizeEstimate9;
    }
  }

  bool _isLocked(int level, bool isPremium) =>
      !isPremium && level > AIOpponentConfig.freeMaxLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isSubscriptionActiveProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickGameSheetTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(height: 6),
              Text(
                l10n.aiLevelSheetFreeNote(
                  AIOpponentConfig.freeMaxLevel,
                  AIOpponentConfig.freeMaxLevel + 1,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.washiDim,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.boardSizeSheetLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.boardSizeQuickNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.washiDim,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in _boardSizes)
                  _boardSizeCard(context, l10n, size),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.aiLevelSheetTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                const columns = 3;
                final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var level = 1; level <= AIOpponentConfig.maxLevel; level++)
                      SizedBox(
                        width: w,
                        child: _levelChip(context, l10n, level, isPremium),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(quickBoardSizeProvider.notifier).state =
                      _selectedBoardSize;
                  Navigator.of(context).pop(_selected);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kin,
                  foregroundColor: AppColors.sumi,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(l10n.aiLevelStartButton),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _boardSizeCard(
    BuildContext context,
    AppLocalizations l10n,
    int size,
  ) {
    final selected = size == _selectedBoardSize;
    return InkWell(
      onTap: () => setState(() => _selectedBoardSize = size),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.kin : AppColors.sumi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.kin, width: selected ? 0 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _boardSizeLabel(l10n, size),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.sumi : AppColors.washi,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _boardSizeEstimate(l10n, size),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? AppColors.sumi.withOpacity(0.7)
                    : AppColors.washiDim,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelChip(
    BuildContext context,
    AppLocalizations l10n,
    int level,
    bool isPremium,
  ) {
    final locked = _isLocked(level, isPremium);
    final selected = !locked && level == _selected;

    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: locked
          ? Icon(Icons.lock_outline, size: 16, color: AppColors.washiDim)
          : null,
      // ロック用アイコンの分だけ幅が狭くなっても「レベル 6」が欠けないよう縮小して収める
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      label: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(l10n.aiLevelOption(level), textAlign: TextAlign.center),
        ),
      ),
      labelStyle: TextStyle(
        color: selected
            ? AppColors.sumi
            : (locked ? AppColors.washiDim : AppColors.washi),
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      selectedColor: AppColors.kin,
      backgroundColor: AppColors.sumi,
      side: BorderSide(color: locked ? AppColors.washiDim : AppColors.kin),
      onSelected: (_) {
        if (locked) {
          // ロック中のレベルは課金画面へ誘導する。
          Navigator.of(context).pop();
          Navigator.of(context).pushNamed('/paywall');
          return;
        }
        setState(() => _selected = level);
      },
    );
  }
}

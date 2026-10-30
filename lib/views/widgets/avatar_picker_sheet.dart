import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/viewmodels/index.dart';

/// アバター選択ボトムシートを表示し、選択されたら
/// [updateAvatarProvider]経由でFirestoreに保存する。
///
/// 保存に失敗した場合はSnackBarでエラーを表示する(呼び出し元は結果を
/// 気にする必要が無い)。
Future<void> showAvatarPickerSheet(BuildContext context, WidgetRef ref) async {
  final currentAvatarId = ref.read(currentUserProvider)?.avatarId;
  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.sumi,
    isScrollControlled: true,
    builder: (_) => _AvatarPickerSheet(currentAvatarId: currentAvatarId),
  );
  if (picked == null) return;

  final l10n = AppLocalizations.of(context)!;
  try {
    await ref.read(updateAvatarProvider)(picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.avatarUpdatedMessage)),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.avatarUpdateFailedMessage('$e'))),
      );
    }
  }
}

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.currentAvatarId});

  final String? currentAvatarId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedId = avatarIconById(currentAvatarId).id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.avatarPickerTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.washi,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final icon in kAvatarIcons)
                  _avatarTile(context, icon, icon.id == selectedId),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarTile(BuildContext context, AvatarIcon icon, bool selected) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(icon.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.kin : AppColors.sumiLine,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.kin,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(icon.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

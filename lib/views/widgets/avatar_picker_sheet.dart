import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/config/avatar_frames.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/viewmodels/index.dart';

/// アバター選択ボトムシートを表示し、選択されたら
/// [updateAvatarProvider]経由でFirestoreに保存する。
///
/// 保存に失敗した場合はSnackBarでエラーを表示する(呼び出し元は結果を
/// 気にする必要が無い)。
Future<void> showAvatarPickerSheet(BuildContext context, WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  final picked = await showModalBottomSheet<_Pick>(
    context: context,
    backgroundColor: AppColors.sumi,
    isScrollControlled: true,
    builder: (_) => _AvatarPickerSheet(
      currentAvatarId: user?.avatarId,
      currentFrameId: user?.frameId,
    ),
  );
  if (picked == null) return;

  final l10n = AppLocalizations.of(context)!;
  final isFrame = picked.isFrame;
  try {
    if (isFrame) {
      await ref.read(updateFrameProvider)(picked.id);
    } else {
      await ref.read(updateAvatarProvider)(picked.id!);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFrame ? l10n.frameUpdatedMessage : l10n.avatarUpdatedMessage,
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFrame
                ? l10n.frameUpdateFailedMessage
                : l10n.avatarUpdateFailedMessage('$e'),
          ),
        ),
      );
    }
  }
}

/// Result of the sheet: either an avatar icon id or a frame id (null =
/// "no frame").
class _Pick {
  const _Pick.avatar(String this.id) : isFrame = false;
  const _Pick.frame(this.id) : isFrame = true;
  final String? id;
  final bool isFrame;
}

class _AvatarPickerSheet extends ConsumerWidget {
  const _AvatarPickerSheet({
    required this.currentAvatarId,
    required this.currentFrameId,
  });

  final String? currentAvatarId;
  final String? currentFrameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked =
        ref.watch(unlockedFrameIdsProvider).valueOrNull ?? const <String>{};
    final l10n = AppLocalizations.of(context)!;
    final selectedId = avatarIconById(currentAvatarId).id;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
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
              const SizedBox(height: 24),
              Text(
                l10n.framePickerTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.washi,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _frameTile(context, l10n, null, true, currentFrameId == null),
              for (final frame in kGoAvatarFrames)
                _frameTile(
                  context,
                  l10n,
                  frame,
                  AvatarFrame.isUnlocked(frame.id, unlocked),
                  frame.id == currentFrameId,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frameTile(
    BuildContext context,
    AppLocalizations l10n,
    AvatarFrame? frame,
    bool isUnlocked,
    bool selected,
  ) {
    final emoji = avatarIconById(currentAvatarId).emoji;
    return ListTile(
      key: ValueKey('frame-tile-${frame?.id ?? 'none'}'),
      contentPadding: EdgeInsets.zero,
      enabled: isUnlocked,
      onTap: isUnlocked
          ? () => Navigator.of(context).pop(_Pick.frame(frame?.id))
          : null,
      leading: Opacity(
        opacity: isUnlocked ? 1 : 0.4,
        child: FramedAvatar(
          emoji: emoji,
          frame: frame,
          size: 44,
          background: AppColors.sumiLine,
        ),
      ),
      title: Text(
        frame == null
            ? l10n.frameNoneLabel
            : localizedFrameName(l10n, frame.id),
        style: TextStyle(
          color: isUnlocked ? AppColors.washi : AppColors.washiDim,
        ),
      ),
      subtitle: frame == null
          ? null
          : Text(
              isUnlocked
                  ? localizedFrameCondition(l10n, frame.id)
                  : '${l10n.frameLockedLabel}: ${localizedFrameCondition(l10n, frame.id)}',
              style: const TextStyle(color: AppColors.washiDim, fontSize: 12),
            ),
      trailing: !isUnlocked
          ? const Icon(Icons.lock, color: AppColors.washiDim)
          : selected
          ? const Icon(Icons.check_circle, color: AppColors.kin)
          : null,
    );
  }

  Widget _avatarTile(BuildContext context, AvatarIcon icon, bool selected) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(_Pick.avatar(icon.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.kin : AppColors.sumiLine,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.kin, width: selected ? 2 : 1),
        ),
        child: Text(icon.emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }
}

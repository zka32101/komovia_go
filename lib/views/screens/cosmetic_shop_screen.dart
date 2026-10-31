import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/config/theme.dart';
import 'package:komovia_go/l10n/app_localizations.dart';
import 'package:komovia_go/models/go_skins.dart';
import 'package:komovia_go/services/purchase_service.dart';
import 'package:komovia_go/viewmodels/index.dart';
import 'package:komovia_go/views/widgets/go_board_grid_painter.dart';
import 'package:komovia_go/views/widgets/go_stone.dart';

/// Board-skin / stone-set shop. No gacha, no virtual currency: every item
/// is either free, included with Premium, or a clearly priced one-time
/// purchase with a full preview shown before buying.
class CosmeticShopScreen extends ConsumerWidget {
  const CosmeticShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final board = ref.watch(selectedBoardSkinProvider);
    final stones = ref.watch(selectedStoneSkinProvider);
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(title: Text(l10n.cosmeticShopTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, l10n.cosmeticShopBoardSection),
          for (final skin in kGoBoardSkins)
            _CosmeticTile(
              key: ValueKey(skin.id),
              item: skin.item,
              equipped: skin.id == board.id,
              preview: _BoardPreview(board: skin, stones: stones),
            ),
          const SizedBox(height: 24),
          _sectionTitle(context, l10n.cosmeticShopStoneSection),
          for (final skin in kGoStoneSkins)
            _CosmeticTile(
              key: ValueKey(skin.id),
              item: skin.item,
              equipped: skin.id == stones.id,
              preview: _BoardPreview(board: board, stones: skin),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.board, required this.stones});
  final GoBoardSkin board;
  final GoStoneSkin stones;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    const pitch = size / 5;
    return Container(
      width: size,
      height: size,
      decoration: board.decoration(),
      child: Stack(children: [
        CustomPaint(
          size: const Size(size, size),
          painter: GoBoardGridPainter(
            boardSize: 5,
            lineColor: board.lineColor,
            starPointColor: null,
          ),
        ),
        Positioned(
          left: pitch * 1.5 - pitch * 0.45,
          top: pitch * 1.5 - pitch * 0.45,
          child: GoStone(radius: pitch * 0.45, isBlack: true, skin: stones),
        ),
        Positioned(
          left: pitch * 2.5 - pitch * 0.45,
          top: pitch * 2.5 - pitch * 0.45,
          child: GoStone(radius: pitch * 0.45, isBlack: false, skin: stones),
        ),
      ]),
    );
  }
}

class _CosmeticTile extends ConsumerStatefulWidget {
  const _CosmeticTile({
    super.key,
    required this.item,
    required this.equipped,
    required this.preview,
  });

  final CosmeticItem item;
  final bool equipped;
  final Widget preview;

  @override
  ConsumerState<_CosmeticTile> createState() => _CosmeticTileState();
}

class _CosmeticTileState extends ConsumerState<_CosmeticTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? successMessage}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserProvider) == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cosmeticLoginRequired)));
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on PurchaseUnavailableException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cosmeticPurchaseFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final owned = ref.watch(cosmeticOwnedProvider(item));

    String status;
    if (item.isFreeForAll) {
      status = l10n.cosmeticFree;
    } else if (owned) {
      status = l10n.cosmeticOwned;
    } else if (item.includedWithSubscription) {
      status = l10n.cosmeticSubscribeToUnlock;
    } else {
      status = '';
    }

    Widget action;
    if (widget.equipped) {
      action = Chip(label: Text(l10n.cosmeticEquipped));
    } else if (owned) {
      action = OutlinedButton(
        onPressed: _busy ? null : () => _run(() => ref.read(selectCosmeticProvider)(item)),
        child: Text(l10n.cosmeticEquip),
      );
    } else if (item.includedWithSubscription) {
      action = FilledButton(
        onPressed: () => Navigator.of(context).pushNamed('/paywall'),
        child: Text(l10n.cosmeticSubscribeToUnlock),
      );
    } else {
      final productId = item.iapProductId!;
      final price = ref.watch(cosmeticProductProvider(productId)).valueOrNull?.price;
      action = FilledButton(
        onPressed: _busy
            ? null
            : () => _run(
                  () => ref.read(purchaseCosmeticProvider)(productId),
                  successMessage: l10n.cosmeticPurchaseSuccess,
                ),
        child: Text(price == null ? l10n.cosmeticBuy : '${l10n.cosmeticBuy} $price'),
      );
    }

    return Card(
      color: AppColors.sumiCard,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          widget.preview,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
                if (status.isNotEmpty)
                  Text(status,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.washiDim)),
              ],
            ),
          ),
          action,
        ]),
      ),
    );
  }
}

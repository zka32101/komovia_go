import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

/// Cosmetic categories used by this app's [CosmeticItem] catalog.
const String kBoardSkinCategory = 'boardSkin';
const String kStoneSkinCategory = 'stoneSkin';

/// Visual definition of a Go board skin. Rendering is done by the existing
/// board container decoration + [GoBoardGridPainter]; a skin only swaps
/// the colours (and optionally a bundled texture image) they use.
class GoBoardSkin {
  const GoBoardSkin({
    required this.item,
    required this.gradient,
    required this.lineColor,
    this.textureAsset,
  });

  final CosmeticItem item;
  final List<Color> gradient;
  final Color lineColor;

  /// Optional bundled texture drawn over the gradient (premium skins).
  final String? textureAsset;

  String get id => item.id;

  BoxDecoration decoration({List<BoxShadow>? boxShadow}) => BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        image: textureAsset == null
            ? null
            : DecorationImage(image: AssetImage(textureAsset!), fit: BoxFit.cover),
        boxShadow: boxShadow,
      );
}

/// Visual definition of a stone set: radial-gradient colour stops for each
/// side, drawn by [GoStone].
class GoStoneSkin {
  const GoStoneSkin({
    required this.item,
    required this.blackColors,
    required this.whiteColors,
    this.glossy = true,
  });

  final CosmeticItem item;
  final List<Color> blackColors;
  final List<Color> whiteColors;

  /// Whether to draw the specular highlight.
  final bool glossy;

  String get id => item.id;
}

const kDefaultBoardSkinId = 'board_kaya_classic';
const kDefaultStoneSkinId = 'stone_classic';

/// Product ids for individually purchasable (non-consumable) skins.
const kBoardSkinStoneSlabProductId = 'goen_skin_board_stone_slab';
const kBoardSkinMinimalProductId = 'goen_skin_board_minimal';
const kStoneSkinGlassProductId = 'goen_skin_stone_glass';
const kStoneSkinJadeProductId = 'goen_skin_stone_jade';

const List<GoBoardSkin> kGoBoardSkins = [
  // --- free ---
  GoBoardSkin(
    item: CosmeticItem(id: kDefaultBoardSkinId, category: kBoardSkinCategory, name: '榧（標準）'),
    gradient: [Color(0xFFC79A5C), Color(0xFFA87C45), Color(0xFFC79A5C)],
    lineColor: Color(0xB83A2711),
  ),
  GoBoardSkin(
    item: CosmeticItem(id: 'board_light_wood', category: kBoardSkinCategory, name: '新榧（明るい木目）'),
    gradient: [Color(0xFFE6C690), Color(0xFFD4AE72), Color(0xFFE6C690)],
    lineColor: Color(0xFF4A3420),
  ),
  GoBoardSkin(
    item: CosmeticItem(id: 'board_flat_sand', category: kBoardSkinCategory, name: 'シンプル（砂色）'),
    gradient: [Color(0xFFDCC9A3), Color(0xFFDCC9A3)],
    lineColor: Color(0xFF2E2418),
  ),
  // --- premium ---
  GoBoardSkin(
    item: CosmeticItem(
      id: 'board_dark_kaya',
      category: kBoardSkinCategory,
      name: '本榧・古色',
      includedWithSubscription: true,
    ),
    gradient: [Color(0xFF7A4E2A), Color(0xFF5C3A1E), Color(0xFF7A4E2A)],
    lineColor: Color(0xFFE8D2A8),
    textureAsset: 'assets/skins/board_dark_kaya.png',
  ),
  GoBoardSkin(
    item: CosmeticItem(
      id: 'board_stone_slab',
      category: kBoardSkinCategory,
      name: '石盤',
      iapProductId: kBoardSkinStoneSlabProductId,
    ),
    gradient: [Color(0xFF6E7378), Color(0xFF4F5459), Color(0xFF6E7378)],
    lineColor: Color(0xFFEDEDED),
    textureAsset: 'assets/skins/board_stone_slab.png',
  ),
  GoBoardSkin(
    item: CosmeticItem(
      id: 'board_minimal',
      category: kBoardSkinCategory,
      name: 'ミニマル（高コントラスト）',
      iapProductId: kBoardSkinMinimalProductId,
    ),
    gradient: [Color(0xFFF4F1EA), Color(0xFFF4F1EA)],
    lineColor: Color(0xFF000000),
  ),
];

const List<GoStoneSkin> kGoStoneSkins = [
  // --- free ---
  GoStoneSkin(
    item: CosmeticItem(id: kDefaultStoneSkinId, category: kStoneSkinCategory, name: '蛤碁石（標準）'),
    blackColors: [Color(0xFF4A4A4A), Color(0xFF151515), Color(0xFF050505)],
    whiteColors: [Color(0xFFFFFFFF), Color(0xFFF1EDE2), Color(0xFFC9C3B3)],
  ),
  GoStoneSkin(
    item: CosmeticItem(id: 'stone_flat', category: kStoneSkinCategory, name: 'フラット'),
    blackColors: [Color(0xFF111111), Color(0xFF111111), Color(0xFF111111)],
    whiteColors: [Color(0xFFF7F7F7), Color(0xFFF7F7F7), Color(0xFFF7F7F7)],
    glossy: false,
  ),
  GoStoneSkin(
    item: CosmeticItem(id: 'stone_slate', category: kStoneSkinCategory, name: '那智黒・マット'),
    blackColors: [Color(0xFF3A3D40), Color(0xFF202225), Color(0xFF0E0F10)],
    whiteColors: [Color(0xFFF5F2EA), Color(0xFFE6E1D3), Color(0xFFCFC8B6)],
    glossy: false,
  ),
  // --- premium ---
  GoStoneSkin(
    item: CosmeticItem(
      id: 'stone_gold_silver',
      category: kStoneSkinCategory,
      name: '金銀',
      includedWithSubscription: true,
    ),
    blackColors: [Color(0xFFFFE9A8), Color(0xFFC9A042), Color(0xFF7A5A12)],
    whiteColors: [Color(0xFFFFFFFF), Color(0xFFD9DDE2), Color(0xFF9097A0)],
  ),
  GoStoneSkin(
    item: CosmeticItem(
      id: 'stone_glass',
      category: kStoneSkinCategory,
      name: '硝子',
      iapProductId: kStoneSkinGlassProductId,
    ),
    blackColors: [Color(0xFF6D7FA8), Color(0xFF1E2A4A), Color(0xFF080C1A)],
    whiteColors: [Color(0xFFFFFFFF), Color(0xFFE3F2F8), Color(0xFFA8C8D6)],
  ),
  GoStoneSkin(
    item: CosmeticItem(
      id: 'stone_jade',
      category: kStoneSkinCategory,
      name: '翡翠と珊瑚',
      iapProductId: kStoneSkinJadeProductId,
    ),
    blackColors: [Color(0xFF7FC7A0), Color(0xFF1F6B47), Color(0xFF0B3321)],
    whiteColors: [Color(0xFFFFF1EC), Color(0xFFF2B8A6), Color(0xFFC9776A)],
  ),
];

/// All purchasable cosmetic product ids (for purchase-stream recovery).
final Set<String> kCosmeticProductIds = {
  for (final s in kGoBoardSkins)
    if (s.item.iapProductId != null) s.item.iapProductId!,
  for (final s in kGoStoneSkins)
    if (s.item.iapProductId != null) s.item.iapProductId!,
};

GoBoardSkin boardSkinById(String? id) => kGoBoardSkins.firstWhere(
      (s) => s.id == id,
      orElse: () => kGoBoardSkins.first,
    );

GoStoneSkin stoneSkinById(String? id) => kGoStoneSkins.firstWhere(
      (s) => s.id == id,
      orElse: () => kGoStoneSkins.first,
    );

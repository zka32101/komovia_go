import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/config/avatar_frames.dart';
import 'package:komovia_go/models/go_skins.dart';

void main() {
  group('lifetime-exclusive board skin', () {
    final skin = boardSkinById(kLifetimeBoardSkinId);

    test('is in the catalog and flagged lifetime-only', () {
      expect(skin.id, kLifetimeBoardSkinId);
      expect(skin.item.includedWithLifetime, isTrue);
      expect(skin.item.includedWithSubscription, isFalse);
      expect(skin.item.iapProductId, isNull);
    });

    test('owned by a lifetime purchaser only', () {
      expect(
        skin.item.isOwnedBy(
          hasActiveSubscription: true,
          purchasedProductIds: const {},
          isLifetimePurchaser: true,
        ),
        isTrue,
      );
      // Monthly/annual subscriber: active subscription but not lifetime.
      expect(
        skin.item.isOwnedBy(
            hasActiveSubscription: true, purchasedProductIds: const {}),
        isFalse,
      );
    });
  });

  group('lifetime supporter frame', () {
    test('is in the catalog and flagged lifetimeExclusive', () {
      final frame = avatarFrameById(FrameIds.lifetimeSupporter);
      expect(frame, isNotNull);
      expect(frame!.lifetimeExclusive, isTrue);
    });

    test('unlocked only once persisted to earnedFrameIds', () {
      expect(computeUnlockedFrameIds(const FrameStats()),
          isNot(contains(FrameIds.lifetimeSupporter)));
      expect(
        computeUnlockedFrameIds(
            const FrameStats(earnedFrameIds: {FrameIds.lifetimeSupporter})),
        contains(FrameIds.lifetimeSupporter),
      );
    });
  });
}

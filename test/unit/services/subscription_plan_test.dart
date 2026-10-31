import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_go/services/purchase_service.dart';

void main() {
  group('SubscriptionPlan (from komovia_core)', () {
    test('is the same type komovia_core exports', () {
      expect(identical(SubscriptionPlan.monthly, core.SubscriptionPlan.monthly),
          isTrue);
    });

    test('keeps the existing value names (lossless for any by-name lookup)',
        () {
      expect(SubscriptionPlan.monthly.name, 'monthly');
      expect(SubscriptionPlan.annual.name, 'annual');
    });

    test('maps sold plans to this app\'s store product ids', () {
      expect(SubscriptionPlan.monthly.productId,
          PurchaseService.monthlyProductId);
      expect(SubscriptionPlan.annual.productId,
          PurchaseService.annualProductId);
    });

    test('lifetime is not sold in this app', () {
      expect(SubscriptionPlan.lifetime.productId, isNull);
    });

    test('product-id reverse lookup still resolves sold plans', () {
      final plan = SubscriptionPlan.values.firstWhere(
          (p) => p.productId == PurchaseService.annualProductId);
      expect(plan, SubscriptionPlan.annual);
    });

    test('entitlement lengths unchanged', () {
      expect(SubscriptionPlan.monthly.entitlementLength,
          const Duration(days: 30));
      expect(SubscriptionPlan.annual.entitlementLength,
          const Duration(days: 365));
    });
  });
}

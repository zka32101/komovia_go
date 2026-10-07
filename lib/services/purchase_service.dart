import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

/// The two plans sold on the paywall.
enum SubscriptionPlan { monthly, annual }

extension SubscriptionPlanProductId on SubscriptionPlan {
  String get productId => switch (this) {
        SubscriptionPlan.monthly => PurchaseService.monthlyProductId,
        SubscriptionPlan.annual => PurchaseService.annualProductId,
      };

  /// How long the entitlement lasts from purchase.
  Duration get entitlementLength => switch (this) {
        SubscriptionPlan.monthly => const Duration(days: 30),
        SubscriptionPlan.annual => const Duration(days: 365),
      };
}

/// Thin wrapper around the platform `in_app_purchase` plugin. Talks
/// directly to the App Store/Play Store IAP APIs (no third-party
/// account needed), but the product IDs below must still be created in
/// App Store Connect / Play Console before a purchase can succeed there.
class PurchaseService {
  static const String monthlyProductId = 'goen_premium_monthly';
  static const String annualProductId = 'goen_premium_annual';
  static const Set<String> productIds = {monthlyProductId, annualProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  final Logger _logger = Logger();

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Looks up a single product's store listing. Returns null (rather than
  /// throwing) when the store can't be reached or the product isn't
  /// configured yet, so callers can show an honest "not available" message
  /// instead of a fake success.
  Future<ProductDetails?> fetchProduct(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null) {
      _logger.e('Failed to query product $productId: ${response.error}');
      return null;
    }
    if (response.notFoundIDs.contains(productId) || response.productDetails.isEmpty) {
      _logger.w('Product not found in store: $productId');
      return null;
    }
    return response.productDetails.first;
  }

  /// Starts the platform purchase flow. The result arrives asynchronously
  /// via [purchaseStream], not as this future's return value.
  Future<bool> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Acknowledges the transaction to the platform store. Required after a
  /// successful purchase, or the store will treat it as unfulfilled and
  /// eventually refund it.
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) {
      return _iap.completePurchase(purchase);
    }
    return Future.value();
  }
}

/// Thrown when a purchase can't proceed because the store or product isn't
/// available (e.g. product IDs not yet configured in App Store
/// Connect/Play Console) — distinct from the user cancelling or a genuine
/// payment failure, so the UI can show an honest, specific message.
class PurchaseUnavailableException implements Exception {
  final String message;
  PurchaseUnavailableException(this.message);

  @override
  String toString() => message;
}

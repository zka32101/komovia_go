import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/index.dart';

/// Converts this [User]'s locally-named subscription fields
/// (`subscriptionActive`/`subscriptionStartDate`/`subscriptionEndDate`)
/// into komovia_core's game-agnostic [Entitlement] shape.
///
/// This app has no per-purchase `plan` field on [User] (see
/// `PurchaseService.SubscriptionPlan`, used only transiently during the
/// purchase flow, never persisted). The one plan that IS recoverable is
/// lifetime: only a lifetime purchase stores an active entitlement with no
/// `subscriptionEndDate`, so that shape maps to [SubscriptionPlan.lifetime]
/// (making [Entitlement.isLifetime] work). Otherwise [Entitlement.plan] is
/// `null` rather than guessed from the start/end date span.
///
/// Per [Entitlement]'s own doc comment, each app's purchase service maps
/// its existing fields onto this shape rather than renaming them -
/// nothing about this app's Firestore schema changes.
extension UserEntitlement on User {
  Entitlement toEntitlement() => Entitlement(
        isActive: subscriptionActive,
        startedAt: subscriptionStartDate,
        expiresAt: subscriptionEndDate,
        plan: isLifetimePurchaser ? SubscriptionPlan.lifetime : null,
      );

  /// Active entitlement with no expiry = a one-time lifetime purchase.
  bool get isLifetimePurchaser =>
      subscriptionActive &&
      subscriptionStartDate != null &&
      subscriptionEndDate == null;
}

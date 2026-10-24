import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_go/models/index.dart';

/// Converts this [User]'s locally-named subscription fields
/// (`subscriptionActive`/`subscriptionStartDate`/`subscriptionEndDate`)
/// into komovia_core's game-agnostic [Entitlement] shape.
///
/// This app has no per-purchase `plan` field on [User] (see
/// `PurchaseService.SubscriptionPlan`, used only transiently during the
/// purchase flow, never persisted) - [Entitlement.plan] is always `null`
/// here rather than guessed from the start/end date span.
///
/// Per [Entitlement]'s own doc comment, each app's purchase service maps
/// its existing fields onto this shape rather than renaming them -
/// nothing about this app's Firestore schema changes.
extension UserEntitlement on User {
  Entitlement toEntitlement() => Entitlement(
        isActive: subscriptionActive,
        startedAt: subscriptionStartDate,
        expiresAt: subscriptionEndDate,
      );
}

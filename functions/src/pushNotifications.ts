/**
 * Sends an actual FCM push whenever a notification is written to
 * notifications/{uid}/messages/{messageId} — the Firestore doc
 * NotificationService.sendNotification (lib/services/notification_service.dart)
 * already creates for every in-app notification type (friend requests,
 * PvP challenges, tournament matches, etc.). Until this function existed,
 * that write was purely Firestore bookkeeping with no actual delivery
 * mechanism: the client only ever polled it via userNotificationsProvider,
 * so a user with the app closed or backgrounded had no way to find out.
 */
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

interface NotificationPreferenceData {
  allNotifications?: boolean;
  friendRequests?: boolean;
  tournamentUpdates?: boolean;
  achievements?: boolean;
  gameInvitations?: boolean;
}

/**
 * Maps a notification's free-form `type` string (see AppNotification's own
 * doc comment in lib/models/notification.dart for the known values) to the
 * matching NotificationPreference category, mirroring
 * NotificationPreference.fromFirestore's own defaulting: a missing
 * preference doc, or a missing individual field on an existing one, means
 * "send" (opt-out model, not opt-in). Exported for unit testing.
 */
export function shouldSendForType(
  pref: NotificationPreferenceData | undefined,
  type: string
): boolean {
  if (!pref) return true;
  if (pref.allNotifications === false) return false;

  if (type.includes("friend") && pref.friendRequests === false) return false;
  if (type.includes("tournament") && pref.tournamentUpdates === false) return false;
  if (type.includes("achievement") && pref.achievements === false) return false;
  if (
    (type.includes("challenge") || type.includes("invitation") || type.includes("game")) &&
    pref.gameInvitations === false
  ) {
    return false;
  }

  return true;
}

/** FCM data payloads must be flat string maps. */
function toStringMap(data: Record<string, unknown> | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!data) return out;
  for (const [key, value] of Object.entries(data)) {
    if (value !== null && value !== undefined) {
      out[key] = String(value);
    }
  }
  return out;
}

export const sendPushOnNotificationCreated = onDocumentCreated(
  {
    document: "notifications/{uid}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const uid = event.params.uid;
    const notification = snapshot.data() as {
      title?: string;
      body?: string;
      type?: string;
      data?: Record<string, unknown>;
    };

    const db = admin.firestore();

    const prefDoc = await db
      .collection("notifications")
      .doc(uid)
      .collection("notificationPreferences")
      .doc("settings")
      .get();
    const pref = prefDoc.exists ? (prefDoc.data() as NotificationPreferenceData) : undefined;

    if (!shouldSendForType(pref, notification.type ?? "general")) {
      logger.info(`Skipping push for ${uid}: opted out of type ${notification.type}`);
      return;
    }

    const tokensSnapshot = await db
      .collection("notifications")
      .doc(uid)
      .collection("fcmTokens")
      .get();

    if (tokensSnapshot.empty) {
      logger.info(`No FCM tokens registered for ${uid}, nothing to send`);
      return;
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.id);
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: notification.title ?? "碁縁",
        body: notification.body ?? "",
      },
      data: toStringMap(notification.data),
    });

    // Tokens the platform reports as no-longer-valid (app uninstalled, etc.)
    // are cleaned up rather than left to fail on every future push forever.
    const staleTokens: string[] = [];
    response.responses.forEach((result, index) => {
      if (
        !result.success &&
        (result.error?.code === "messaging/invalid-registration-token" ||
          result.error?.code === "messaging/registration-token-not-registered")
      ) {
        staleTokens.push(tokens[index]);
      }
    });

    if (staleTokens.length > 0) {
      const batch = db.batch();
      for (const token of staleTokens) {
        batch.delete(
          db.collection("notifications").doc(uid).collection("fcmTokens").doc(token)
        );
      }
      await batch.commit();
      logger.info(`Removed ${staleTokens.length} stale FCM token(s) for ${uid}`);
    }

    logger.info(
      `Push sent for ${uid}: ${response.successCount}/${tokens.length} succeeded`
    );
  }
);

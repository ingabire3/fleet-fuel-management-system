import { NotificationChannel } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { logger } from "../../config/logger";
import { NOTIFICATION_EVENTS, NotificationEventKey, buildEmailTemplate } from "./notification-events";

export interface EmitOptions {
  /** Deduplicates the in-app notification per (userId, dedupeKey). */
  dedupeKey?: string;
  /** Id of the entity this notification relates to (fuel request, vehicle, etc.). */
  relatedId?: string;
}

/**
 * Emits a notification event to a set of recipients.
 * - IN_APP notifications are written synchronously so the UI updates immediately.
 * - EMAIL/PUSH notifications are written to the NotificationLog outbox table,
 *   processed asynchronously by `jobs/notificationOutboxWorker.ts`.
 */
export async function emit<K extends NotificationEventKey>(
  eventKey: K,
  recipientIds: string[],
  context: Parameters<(typeof NOTIFICATION_EVENTS)[K]["content"]>[0],
  options: EmitOptions = {}
): Promise<void> {
  if (recipientIds.length === 0) return;

  const def = NOTIFICATION_EVENTS[eventKey];
  const content = def.content(context as never);
  const channels = def.channels as NotificationChannel[];

  for (const userId of recipientIds) {
    if (channels.includes(NotificationChannel.IN_APP)) {
      await upsertInAppNotification(userId, eventKey, content, def.category, def.priority, options);
    }

    for (const channel of channels) {
      if (channel === NotificationChannel.IN_APP) continue;

      const payload =
        channel === NotificationChannel.EMAIL
          ? buildEmailTemplate(eventKey, content, context as never)
          : { title: content.title, message: content.message, data: { type: eventKey, relatedId: options.relatedId } };

      await prisma.notificationLog
        .create({
          data: {
            userId,
            channel,
            eventType: eventKey,
            payload: payload as object,
            relatedNotificationId: options.relatedId,
          },
        })
        .catch((err) => logger.error({ err, eventKey, channel }, "Failed to enqueue notification log"));
    }
  }
}

async function upsertInAppNotification(
  userId: string,
  eventKey: string,
  content: { title: string; message: string },
  category: (typeof NOTIFICATION_EVENTS)[NotificationEventKey]["category"],
  priority: (typeof NOTIFICATION_EVENTS)[NotificationEventKey]["priority"],
  options: EmitOptions
): Promise<void> {
  const data = {
    userId,
    title: content.title,
    message: content.message,
    type: eventKey,
    category,
    priority,
    relatedId: options.relatedId,
    dedupeKey: options.dedupeKey,
  };

  try {
    if (options.dedupeKey) {
      await prisma.notification.upsert({
        where: { userId_dedupeKey: { userId, dedupeKey: options.dedupeKey } },
        update: { ...data, isRead: false, readAt: null, createdAt: new Date() },
        create: data,
      });
    } else {
      await prisma.notification.create({ data });
    }
  } catch (err) {
    logger.error({ err, eventKey }, "Failed to write in-app notification");
  }
}

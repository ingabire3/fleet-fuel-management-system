import { NotificationChannel, NotificationDeliveryStatus, Prisma } from "@prisma/client";
import { logger } from "../config/logger";
import { prisma } from "../config/prisma";
import { EmailTemplate, sendImmediateEmail } from "../modules/notifications/email.service";
import { PushPayload, sendPushToUser } from "../modules/notifications/push.service";

const BATCH_SIZE = 50;
const MAX_ATTEMPTS = 5;

/** Processes pending (and retryable failed) NotificationLog rows: sends EMAIL via SMTP and PUSH via Firebase. */
export async function processNotificationOutbox(): Promise<void> {
  const logs = await prisma.notificationLog.findMany({
    where: {
      OR: [
        { status: NotificationDeliveryStatus.PENDING },
        { status: NotificationDeliveryStatus.FAILED, attempts: { lt: MAX_ATTEMPTS } },
      ],
    },
    orderBy: { createdAt: "asc" },
    take: BATCH_SIZE,
    include: { user: { select: { email: true } } },
  });

  for (const log of logs) {
    try {
      switch (log.channel) {
        case NotificationChannel.EMAIL:
          await sendImmediateEmail(log.user.email, log.payload as unknown as EmailTemplate);
          break;
        case NotificationChannel.PUSH: {
          const result = await sendPushToUser(log.userId, log.payload as unknown as PushPayload);
          if (result.staleTokens.length > 0) {
            logger.info({ userId: log.userId, staleTokens: result.staleTokens.length }, "Deactivated stale push tokens");
          }
          break;
        }
        default:
          await prisma.notificationLog.update({
            where: { id: log.id },
            data: { status: NotificationDeliveryStatus.SKIPPED, attempts: { increment: 1 } },
          });
          continue;
      }

      await prisma.notificationLog.update({
        where: { id: log.id },
        data: { status: NotificationDeliveryStatus.SENT, sentAt: new Date(), attempts: { increment: 1 }, lastError: null },
      });
    } catch (err) {
      logger.error({ err, logId: log.id, channel: log.channel }, "Failed to deliver notification");
      await prisma.notificationLog.update({
        where: { id: log.id },
        data: {
          status: NotificationDeliveryStatus.FAILED,
          attempts: { increment: 1 },
          lastError: err instanceof Error ? err.message : String(err),
        } satisfies Prisma.NotificationLogUpdateInput,
      });
    }
  }
}

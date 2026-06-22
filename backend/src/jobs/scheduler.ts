import cron from "node-cron";
import { logger } from "../config/logger";
import { runMonthlyAllocationJob } from "./monthlyAllocationJob";
import { processNotificationOutbox } from "./notificationOutboxWorker";
import { runSessionCleanupJob } from "./sessionCleanupJob";

/** Registers all scheduled background jobs. Call once on server startup. */
export function startScheduler(): void {
  cron.schedule("* * * * *", () => {
    processNotificationOutbox().catch((err) => logger.error({ err }, "Notification outbox worker failed"));
  });

  cron.schedule("5 0 1 * *", () => {
    runMonthlyAllocationJob().catch((err) => logger.error({ err }, "Monthly allocation job failed"));
  });

  cron.schedule("0 3 * * *", () => {
    runSessionCleanupJob().catch((err) => logger.error({ err }, "Session cleanup job failed"));
  });

  logger.info("Background job scheduler started");
}

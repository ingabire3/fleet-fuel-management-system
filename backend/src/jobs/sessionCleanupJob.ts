import { prisma } from "../config/prisma";
import { logger } from "../config/logger";

const SESSION_RETENTION_DAYS = 30;

/** Purges expired/revoked sessions and expired rate-limit entries to keep auth tables small. */
export async function runSessionCleanupJob(): Promise<void> {
  const retentionCutoff = new Date(Date.now() - SESSION_RETENTION_DAYS * 24 * 60 * 60 * 1000);
  const now = new Date();

  const [sessions, rateLimitEntries] = await Promise.all([
    prisma.session.deleteMany({
      where: {
        OR: [{ expiresAt: { lt: retentionCutoff } }, { revokedAt: { lt: retentionCutoff } }],
      },
    }),
    prisma.rateLimitEntry.deleteMany({ where: { expiresAt: { lt: now } } }),
  ]);

  logger.info({ sessions: sessions.count, rateLimitEntries: rateLimitEntries.count }, "Session cleanup job completed");
}

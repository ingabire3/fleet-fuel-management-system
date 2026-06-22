import { prisma } from "../config/prisma";

/**
 * Increments a persisted counter for `key`. If the previous window expired, the
 * counter resets. Returns the current count and whether the limit is exceeded.
 * Used for account-based lockouts (e.g. failed login attempts per email).
 */
export async function incrementAndCheck(
  key: string,
  maxCount: number,
  windowMs: number
): Promise<{ count: number; limited: boolean }> {
  const now = new Date();
  const existing = await prisma.rateLimitEntry.findUnique({ where: { key } });

  if (!existing || existing.expiresAt < now) {
    await prisma.rateLimitEntry.upsert({
      where: { key },
      update: { count: 1, windowStart: now, expiresAt: new Date(now.getTime() + windowMs) },
      create: { key, count: 1, windowStart: now, expiresAt: new Date(now.getTime() + windowMs) },
    });
    return { count: 1, limited: 1 >= maxCount };
  }

  const updated = await prisma.rateLimitEntry.update({
    where: { key },
    data: { count: { increment: 1 } },
  });

  return { count: updated.count, limited: updated.count >= maxCount };
}

/** Clears a rate-limit counter (e.g. on successful login). */
export async function resetLimit(key: string): Promise<void> {
  await prisma.rateLimitEntry.deleteMany({ where: { key } });
}

/** Checks whether `key` is currently locked out, without incrementing it. */
export async function isLimited(key: string, maxCount: number): Promise<boolean> {
  const entry = await prisma.rateLimitEntry.findUnique({ where: { key } });
  if (!entry || entry.expiresAt < new Date()) return false;
  return entry.count >= maxCount;
}

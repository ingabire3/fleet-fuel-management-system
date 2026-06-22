import { getFirebaseApp } from "../../config/firebase";
import { logger } from "../../config/logger";
import { prisma } from "../../config/prisma";

export interface PushPayload {
  title: string;
  message: string;
  data?: Record<string, string | undefined>;
}

export interface PushResult {
  sent: boolean;
  staleTokens: string[];
}

const STALE_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/** Sends a push notification to every active device of `userId`. Returns false (no-op) if Firebase is not configured or the user has no registered devices. */
export async function sendPushToUser(userId: string, payload: PushPayload): Promise<PushResult> {
  const app = getFirebaseApp();
  if (!app) return { sent: false, staleTokens: [] };

  const devices = await prisma.deviceToken.findMany({
    where: { userId, isActive: true, deletedAt: null, token: { not: null } },
  });
  const tokens = devices.map((device) => device.token).filter((token): token is string => !!token);
  if (tokens.length === 0) return { sent: false, staleTokens: [] };

  const data: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload.data ?? {})) {
    if (value !== undefined) data[key] = value;
  }

  const response = await app.messaging().sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.message },
    data,
  });

  const staleTokens: string[] = [];
  response.responses.forEach((result, index) => {
    if (result.success) return;
    const code = result.error?.code;
    if (code && STALE_TOKEN_ERROR_CODES.has(code)) {
      staleTokens.push(tokens[index]);
    } else {
      logger.error({ err: result.error, token: tokens[index] }, "Push notification delivery failed");
    }
  });

  if (staleTokens.length > 0) {
    await prisma.deviceToken.updateMany({
      where: { token: { in: staleTokens } },
      data: { isActive: false },
    });
  }

  return { sent: response.successCount > 0, staleTokens };
}

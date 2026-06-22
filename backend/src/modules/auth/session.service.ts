import { DeviceType, User } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { env } from "../../config/env";
import { addDuration } from "../../lib/time";
import { UnauthorizedError } from "../../lib/errors";
import { generateRefreshToken, hashRefreshToken, signAccessToken } from "./token.service";

export interface DeviceContext {
  deviceId?: string;
  deviceType?: DeviceType;
  deviceName?: string;
  ipAddress?: string;
  userAgent?: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
}

/** Creates a new session (refresh token) and a corresponding access token. */
export async function createSession(user: User, device: DeviceContext): Promise<TokenPair> {
  const { token, hash } = generateRefreshToken();
  const expiresAt = addDuration(new Date(), env.JWT_REFRESH_EXPIRES_IN);

  const session = await prisma.session.create({
    data: {
      userId: user.id,
      refreshToken: hash,
      deviceId: device.deviceId,
      ipAddress: device.ipAddress,
      userAgent: device.userAgent,
      expiresAt,
    },
  });

  const accessToken = signAccessToken({
    sub: user.id,
    role: user.role,
    organizationId: user.organizationId,
    sessionId: session.id,
  });

  return { accessToken, refreshToken: token, expiresAt };
}

/** Verifies a refresh token, revokes the old session, and issues a new token pair (rotation). */
export async function rotateSession(refreshToken: string, device: DeviceContext): Promise<TokenPair> {
  const hash = hashRefreshToken(refreshToken);
  const session = await prisma.session.findUnique({ where: { refreshToken: hash }, include: { user: true } });

  if (!session || session.revokedAt || session.expiresAt < new Date()) {
    throw new UnauthorizedError("Invalid or expired refresh token");
  }

  await prisma.session.update({ where: { id: session.id }, data: { revokedAt: new Date() } });

  return createSession(session.user, device);
}

export async function revokeSession(refreshToken: string): Promise<void> {
  const hash = hashRefreshToken(refreshToken);
  await prisma.session.updateMany({
    where: { refreshToken: hash, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function revokeAllSessions(userId: string): Promise<void> {
  await prisma.session.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function listActiveSessions(userId: string) {
  return prisma.session.findMany({
    where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
    select: { id: true, deviceId: true, ipAddress: true, userAgent: true, createdAt: true, expiresAt: true },
    orderBy: { createdAt: "desc" },
  });
}

export async function revokeSessionById(userId: string, sessionId: string): Promise<void> {
  await prisma.session.updateMany({
    where: { id: sessionId, userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

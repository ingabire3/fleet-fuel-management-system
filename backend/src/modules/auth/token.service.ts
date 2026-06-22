import crypto from "crypto";
import jwt, { SignOptions } from "jsonwebtoken";
import { env } from "../../config/env";
import { AccessTokenPayload } from "../../types/auth";

export function signAccessToken(payload: AccessTokenPayload): string {
  const options: SignOptions = { expiresIn: env.JWT_ACCESS_EXPIRES_IN as SignOptions["expiresIn"] };
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, options);
}

/** Generates a random opaque refresh token. Returns both the raw token (sent to the
 *  client) and its SHA-256 hash (stored in `Session.refreshToken`). */
export function generateRefreshToken(): { token: string; hash: string } {
  const token = crypto.randomBytes(48).toString("hex");
  return { token, hash: hashRefreshToken(token) };
}

export function hashRefreshToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/** Short-lived JWT identifying a pending login (awaiting OTP) or a verified password-reset request. */
export function signTransientToken(payload: Record<string, unknown>, expiresIn: SignOptions["expiresIn"] = "10m"): string {
  return jwt.sign(payload, env.OTP_TOKEN_SECRET, { expiresIn });
}

export function verifyTransientToken<T>(token: string): T {
  return jwt.verify(token, env.OTP_TOKEN_SECRET) as T;
}

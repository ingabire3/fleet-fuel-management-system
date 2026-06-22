import bcrypt from "bcrypt";
import { OtpPurpose, OtpStatus, Prisma } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { env } from "../../config/env";
import { BadRequestError } from "../../lib/errors";

const OTP_LENGTH = 6;
const BCRYPT_ROUNDS = 10;

function generateNumericCode(): string {
  const max = 10 ** OTP_LENGTH;
  const code = Math.floor(Math.random() * max);
  return code.toString().padStart(OTP_LENGTH, "0");
}

/**
 * Generates a new OTP for `userId`/`purpose`, invalidating any prior pending
 * codes for the same purpose. Returns the plaintext code (caller sends it via
 * email - only the bcrypt hash is persisted).
 */
export async function generateOtp(
  userId: string,
  purpose: OtpPurpose,
  metadata?: Prisma.InputJsonValue
): Promise<string> {
  await prisma.otpCode.updateMany({
    where: { userId, purpose, status: OtpStatus.PENDING },
    data: { status: OtpStatus.EXPIRED },
  });

  const code = generateNumericCode();
  const codeHash = await bcrypt.hash(code, BCRYPT_ROUNDS);
  const expiresAt = new Date(Date.now() + env.OTP_TTL_MINUTES * 60 * 1000);

  await prisma.otpCode.create({
    data: { userId, purpose, codeHash, expiresAt, metadata },
  });

  return code;
}

/**
 * Verifies `code` against the latest pending OTP for `userId`/`purpose`.
 * Throws BadRequestError on missing/expired/exhausted/mismatched codes.
 * On success marks the code VERIFIED+CONSUMED so it cannot be reused.
 */
export async function verifyOtp(userId: string, purpose: OtpPurpose, code: string): Promise<void> {
  const otp = await prisma.otpCode.findFirst({
    where: { userId, purpose, status: OtpStatus.PENDING },
    orderBy: { createdAt: "desc" },
  });

  if (!otp) {
    throw new BadRequestError("No pending verification code. Please request a new one.");
  }

  if (otp.expiresAt < new Date()) {
    await prisma.otpCode.update({ where: { id: otp.id }, data: { status: OtpStatus.EXPIRED } });
    throw new BadRequestError("Verification code has expired. Please request a new one.");
  }

  if (otp.attempts >= otp.maxAttempts) {
    await prisma.otpCode.update({ where: { id: otp.id }, data: { status: OtpStatus.EXPIRED } });
    throw new BadRequestError("Too many incorrect attempts. Please request a new code.");
  }

  const matches = await bcrypt.compare(code, otp.codeHash);

  if (!matches) {
    const attempts = otp.attempts + 1;
    await prisma.otpCode.update({
      where: { id: otp.id },
      data: { attempts, status: attempts >= otp.maxAttempts ? OtpStatus.EXPIRED : OtpStatus.PENDING },
    });
    throw new BadRequestError("Incorrect verification code.");
  }

  await prisma.otpCode.update({
    where: { id: otp.id },
    data: { status: OtpStatus.VERIFIED, verifiedAt: new Date() },
  });
}

import bcrypt from "bcrypt";
import { OtpPurpose, User } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { AUTH, DEFAULT_ORG_CODE } from "../../config/constants";
import { BadRequestError, ConflictError, ForbiddenError, TooManyRequestsError, UnauthorizedError } from "../../lib/errors";
import { getBooleanSetting } from "../../lib/settings";
import { incrementAndCheck, isLimited, resetLimit } from "../../lib/rateLimitStore";
import {
  accountCreatedTemplate,
  newDeviceLoginTemplate,
  otpEmailTemplate,
  passwordChangedTemplate,
  sendImmediateEmail,
} from "../notifications/email.service";
import { emit } from "../notifications/notification-dispatcher";
import { generateOtp, verifyOtp } from "./otp.service";
import {
  createSession,
  DeviceContext,
  listActiveSessions,
  revokeAllSessions,
  revokeSession,
  revokeSessionById as revokeSessionByIdInternal,
  rotateSession,
  TokenPair,
} from "./session.service";
import { signTransientToken, verifyTransientToken } from "./token.service";
import {
  LoginInput,
  PasswordResetConfirmInput,
  RegisterInput,
  VerifyLoginOtpInput,
} from "./auth.validators";

export interface PublicUser {
  id: string;
  email: string;
  fullName: string;
  role: User["role"];
  organizationId: string;
  isApproved: boolean;
  isActive: boolean;
  /** false only for DRIVER accounts that haven't completed their profile setup yet */
  isProfileComplete: boolean;
}

export interface LoginResult {
  requiresOtp: false;
  tokens: TokenPair;
  user: PublicUser;
}

export interface LoginOtpRequired {
  requiresOtp: true;
  transientToken: string;
}

interface TransientLoginPayload {
  sub: string;
  purpose: OtpPurpose;
  deviceId?: string;
}

function sanitizeUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    role: user.role,
    organizationId: user.organizationId,
    isApproved: user.isApproved,
    isActive: user.isActive,
    isProfileComplete: user.role !== "DRIVER" || user.profileCompletedAt !== null,
  };
}

function loginLockKey(email: string): string {
  return `login:${email.toLowerCase()}`;
}

export async function registerUser(input: RegisterInput): Promise<PublicUser> {
  const existing = await prisma.user.findUnique({ where: { email: input.email } });
  if (existing) {
    throw new ConflictError("An account with this email already exists");
  }

  const org = await prisma.organization.findUniqueOrThrow({ where: { code: DEFAULT_ORG_CODE } });
  const passwordHash = await bcrypt.hash(input.password, AUTH.BCRYPT_ROUNDS);

  const user = await prisma.user.create({
    data: {
      organizationId: org.id,
      email: input.email,
      passwordHash,
      fullName: input.fullName,
      phone: input.phone,
      employeeId: input.employeeId,
      departmentId: input.departmentId,
      homeAddress: input.homeAddress,
      homeLat: input.homeLat,
      homeLng: input.homeLng,
      workSiteName: input.workSiteName,
      workSiteLat: input.workSiteLat,
      workSiteLng: input.workSiteLng,
      fuelType: input.fuelType,
    },
  });

  await sendImmediateEmail(user.email, accountCreatedTemplate(user.fullName));

  return sanitizeUser(user);
}

export async function login(input: LoginInput, device: DeviceContext): Promise<LoginResult | LoginOtpRequired> {
  const user = await prisma.user.findFirst({ where: { email: input.email, deletedAt: null } });

  if (!user) {
    throw new UnauthorizedError("Invalid email or password");
  }

  const lockKey = loginLockKey(user.email);

  if (await isLimited(lockKey, AUTH.LOGIN_MAX_ATTEMPTS)) {
    throw new TooManyRequestsError("Too many failed login attempts. Please try again later.");
  }

  const passwordMatches = await bcrypt.compare(input.password, user.passwordHash);

  if (!passwordMatches) {
    await incrementAndCheck(lockKey, AUTH.LOGIN_MAX_ATTEMPTS, AUTH.LOGIN_LOCKOUT_WINDOW_MS);
    await recordLoginHistory(user.id, false, device, "Invalid password");
    throw new UnauthorizedError("Invalid email or password");
  }

  await resetLimit(lockKey);

  if (!user.isActive) {
    await recordLoginHistory(user.id, false, device, "Account disabled");
    throw new ForbiddenError("Your account has been disabled. Contact your administrator.");
  }

  if (!user.isApproved) {
    await recordLoginHistory(user.id, false, device, "Account pending approval");
    throw new ForbiddenError("Your account is pending approval.");
  }

  const requireLoginOtp = await getBooleanSetting(user.organizationId, "REQUIRE_LOGIN_OTP");
  const newDevice = device.deviceId ? await isNewDevice(user.id, device.deviceId) : false;

  if (requireLoginOtp || newDevice) {
    const purpose = newDevice ? OtpPurpose.NEW_DEVICE : OtpPurpose.LOGIN;
    const code = await generateOtp(user.id, purpose, { deviceId: device.deviceId });
    await sendImmediateEmail(user.email, otpEmailTemplate(code, purpose));

    const transientToken = signTransientToken(
      { sub: user.id, purpose, deviceId: device.deviceId } satisfies TransientLoginPayload,
      "10m"
    );

    return { requiresOtp: true, transientToken };
  }

  return finalizeLogin(user, device);
}

export async function verifyLoginOtp(input: VerifyLoginOtpInput, device: DeviceContext): Promise<LoginResult> {
  const payload = verifyTransientToken<TransientLoginPayload>(input.transientToken);

  await verifyOtp(payload.sub, payload.purpose, input.code);

  const user = await prisma.user.findUniqueOrThrow({ where: { id: payload.sub } });
  const resolvedDevice: DeviceContext = { ...device, deviceId: device.deviceId ?? payload.deviceId };

  if (payload.purpose === OtpPurpose.NEW_DEVICE) {
    const deviceInfo = resolvedDevice.userAgent ?? resolvedDevice.deviceId ?? "unknown device";
    await sendImmediateEmail(user.email, newDeviceLoginTemplate(user.fullName, deviceInfo));
    await emit("login_alert_new_device", [user.id], { deviceInfo });
  }

  return finalizeLogin(user, resolvedDevice);
}

export async function refreshTokens(refreshToken: string, device: DeviceContext): Promise<TokenPair> {
  return rotateSession(refreshToken, device);
}

export async function logout(refreshToken: string): Promise<void> {
  await revokeSession(refreshToken);
}

export async function logoutAll(userId: string): Promise<void> {
  await revokeAllSessions(userId);
}

export async function getSessions(userId: string) {
  return listActiveSessions(userId);
}

export async function revokeSessionById(userId: string, sessionId: string): Promise<void> {
  await revokeSessionByIdInternal(userId, sessionId);
}

export async function requestPasswordReset(email: string): Promise<void> {
  const user = await prisma.user.findFirst({ where: { email, deletedAt: null } });
  if (!user) return; // avoid email enumeration

  const code = await generateOtp(user.id, OtpPurpose.PASSWORD_RESET);
  await sendImmediateEmail(user.email, otpEmailTemplate(code, OtpPurpose.PASSWORD_RESET));
}

export async function verifyPasswordResetOtp(email: string, code: string): Promise<string> {
  const user = await prisma.user.findFirst({ where: { email, deletedAt: null } });
  if (!user) {
    throw new BadRequestError("Incorrect verification code.");
  }

  await verifyOtp(user.id, OtpPurpose.PASSWORD_RESET, code);

  return signTransientToken({ sub: user.id, purpose: "PASSWORD_RESET_CONFIRM" }, "10m");
}

export async function confirmPasswordReset(input: PasswordResetConfirmInput): Promise<void> {
  const payload = verifyTransientToken<{ sub: string; purpose: string }>(input.resetToken);

  if (payload.purpose !== "PASSWORD_RESET_CONFIRM") {
    throw new BadRequestError("Invalid or expired reset token");
  }

  const passwordHash = await bcrypt.hash(input.newPassword, AUTH.BCRYPT_ROUNDS);
  const user = await prisma.user.update({ where: { id: payload.sub }, data: { passwordHash } });

  await revokeAllSessions(user.id);
  await sendImmediateEmail(user.email, passwordChangedTemplate(user.fullName));
  await emit("password_changed", [user.id], {});
}

async function finalizeLogin(user: User, device: DeviceContext): Promise<LoginResult> {
  const tokens = await createSession(user, device);
  await recordLoginHistory(user.id, true, device);

  if (device.deviceId) {
    await touchDeviceToken(user.id, device.deviceId, device);
  }

  return { requiresOtp: false, tokens, user: sanitizeUser(user) };
}

async function isNewDevice(userId: string, deviceId: string): Promise<boolean> {
  const existing = await prisma.deviceToken.findUnique({
    where: { userId_deviceId: { userId, deviceId } },
  });
  return !existing || existing.deletedAt !== null;
}

async function touchDeviceToken(userId: string, deviceId: string, device: DeviceContext): Promise<void> {
  await prisma.deviceToken.upsert({
    where: { userId_deviceId: { userId, deviceId } },
    update: {
      lastUsedAt: new Date(),
      isActive: true,
      deletedAt: null,
      deviceType: device.deviceType,
      deviceName: device.deviceName,
    },
    create: {
      userId,
      deviceId,
      lastUsedAt: new Date(),
      deviceType: device.deviceType,
      deviceName: device.deviceName,
    },
  });
}

async function recordLoginHistory(
  userId: string,
  success: boolean,
  device: DeviceContext,
  failureReason?: string
): Promise<void> {
  await prisma.loginHistory.create({
    data: {
      userId,
      success,
      ipAddress: device.ipAddress,
      userAgent: device.userAgent,
      deviceId: device.deviceId,
      failureReason,
    },
  });
}

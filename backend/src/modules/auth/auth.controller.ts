import { Request, Response } from "express";
import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as authService from "./auth.service";
import { DeviceContext } from "./session.service";

function deviceContext(req: Request): DeviceContext {
  const body = req.body as { deviceId?: string; deviceType?: DeviceContext["deviceType"]; deviceName?: string };
  return {
    deviceId: body.deviceId,
    deviceType: body.deviceType,
    deviceName: body.deviceName,
    ipAddress: req.ip,
    userAgent: req.headers["user-agent"],
  };
}

export const register = asyncHandler(async (req, res) => {
  const user = await authService.registerUser(req.body);
  res.status(201).json({ data: user });
});

export const login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body, deviceContext(req));
  res.status(200).json({ data: result });
});

export const verifyLoginOtp = asyncHandler(async (req, res) => {
  const result = await authService.verifyLoginOtp(req.body, deviceContext(req));
  res.status(200).json({ data: result });
});

export const refresh = asyncHandler(async (req, res) => {
  const tokens = await authService.refreshTokens(req.body.refreshToken, deviceContext(req));
  res.status(200).json({ data: tokens });
});

export const logout = asyncHandler(async (req, res) => {
  await authService.logout(req.body.refreshToken);
  res.status(204).send();
});

export const logoutAll = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await authService.logoutAll(req.user.id);
  res.status(204).send();
});

export const requestPasswordReset = asyncHandler(async (req, res) => {
  await authService.requestPasswordReset(req.body.email);
  res.status(200).json({ data: { message: "If an account exists for this email, a verification code has been sent." } });
});

export const verifyPasswordResetOtp = asyncHandler(async (req, res) => {
  const resetToken = await authService.verifyPasswordResetOtp(req.body.email, req.body.code);
  res.status(200).json({ data: { resetToken } });
});

export const confirmPasswordReset = asyncHandler(async (req, res) => {
  await authService.confirmPasswordReset(req.body);
  res.status(200).json({ data: { message: "Password updated successfully." } });
});

export const getSessions = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) throw new UnauthorizedError();
  const sessions = await authService.getSessions(req.user.id);
  res.status(200).json({ data: sessions });
});

export const revokeSession = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) throw new UnauthorizedError();
  await authService.revokeSessionById(req.user.id, req.params.id);
  res.status(204).send();
});

export const me = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) throw new UnauthorizedError();
  res.status(200).json({ data: req.user });
});

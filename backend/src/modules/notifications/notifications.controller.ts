import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as deviceTokensService from "./device-tokens.service";
import * as notificationsService from "./notifications.service";
import { ListNotificationsQuery, RegisterDeviceTokenInput } from "./notifications.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await notificationsService.listNotifications(req.user, req.query as unknown as ListNotificationsQuery);
  res.status(200).json(result);
});

export const markAsRead = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const notification = await notificationsService.markAsRead(req.user, req.params.id);
  res.status(200).json({ data: notification });
});

export const markAllAsRead = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await notificationsService.markAllAsRead(req.user);
  res.status(204).send();
});

export const registerDevice = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const device = await deviceTokensService.registerDeviceToken(req.user, req.body as RegisterDeviceTokenInput);
  res.status(200).json({ data: device });
});

export const unregisterDevice = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await deviceTokensService.unregisterDeviceToken(req.user, req.params.deviceId);
  res.status(204).send();
});

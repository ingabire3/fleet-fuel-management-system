import { z } from "zod";
import { queryBool } from "../../lib/queryBool";

const categoryEnum = z.enum(["FUEL_REQUEST", "AI_ALERT", "VEHICLE", "STIPEND", "BUDGET", "ACCOUNT", "SECURITY", "SYSTEM"]);
const deviceTypeEnum = z.enum(["ANDROID", "IOS", "WEB", "UNKNOWN"]);

export const notificationIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listNotificationsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  isRead: queryBool,
  category: categoryEnum.optional(),
});

export const registerDeviceTokenSchema = z.object({
  deviceId: z.string().min(1).max(255),
  token: z.string().min(1).max(500).nullable().optional(),
  deviceType: deviceTypeEnum.optional(),
  deviceName: z.string().max(255).optional(),
});

export const deviceIdParamsSchema = z.object({
  deviceId: z.string().min(1).max(255),
});

export type ListNotificationsQuery = z.infer<typeof listNotificationsQuerySchema>;
export type RegisterDeviceTokenInput = z.infer<typeof registerDeviceTokenSchema>;

import { z } from "zod";

export const permissionTypeEnum = z.enum(["VEHICLE_MANAGEMENT", "FINANCIAL_MANAGEMENT", "DRIVER_MANAGEMENT"]);

export const userIdParamsSchema = z.object({ id: z.string().uuid() });

export const grantPermissionSchema = z.object({
  permission: permissionTypeEnum,
  reason: z.string().max(500).optional(),
});

export const permissionParamsSchema = z.object({
  id: z.string().uuid(),
  permission: permissionTypeEnum,
});

export type GrantPermissionInput = z.infer<typeof grantPermissionSchema>;

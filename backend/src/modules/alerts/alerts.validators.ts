import { z } from "zod";

const alertTypeEnum = z.enum([
  "POSSIBLE_THEFT",
  "LOW_FUEL",
  "RAPID_FUEL_DROP",
  "UNUSUAL_ROUTE",
  "OVER_CONSUMPTION",
  "ROUTE_DETOUR",
  "BUDGET_EXCEEDED",
  "STIPEND_CHANGED",
]);

const alertSeverityEnum = z.enum(["CRITICAL", "HIGH", "MEDIUM", "LOW"]);
const alertStatusEnum = z.enum(["OPEN", "ACKNOWLEDGED", "RESOLVED", "DISMISSED"]);

export const alertIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listAlertsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  status: alertStatusEnum.optional(),
  alertType: alertTypeEnum.optional(),
  severity: alertSeverityEnum.optional(),
  driverId: z.string().uuid().optional(),
  vehicleId: z.string().uuid().optional(),
});

export const updateAlertStatusSchema = z.object({
  status: z.enum(["ACKNOWLEDGED", "RESOLVED", "DISMISSED"]),
});

export type ListAlertsQuery = z.infer<typeof listAlertsQuerySchema>;
export type UpdateAlertStatusInput = z.infer<typeof updateAlertStatusSchema>;

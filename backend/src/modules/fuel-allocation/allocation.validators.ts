import { z } from "zod";

export const driverIdParamsSchema = z.object({
  driverId: z.string().uuid(),
});

export const allocationHistoryQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
});

export const recomputeAllocationSchema = z.object({
  reason: z.string().min(1).max(120).optional(),
});

export type AllocationHistoryQuery = z.infer<typeof allocationHistoryQuerySchema>;
export type RecomputeAllocationInput = z.infer<typeof recomputeAllocationSchema>;

import { z } from "zod";

const statusEnum = z.enum([
  "PENDING",
  "FLEET_MANAGER_APPROVED",
  "FLEET_MANAGER_REJECTED",
  "FINANCE_APPROVED",
  "FINANCE_REJECTED",
  "CANCELLED",
]);

export const fuelRequestIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listFuelRequestsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  status: statusEnum.optional(),
  driverId: z.string().uuid().optional(),
});

export const createFuelRequestSchema = z.object({
  requestedQuantityL: z.coerce.number().positive("Fuel quantity must be greater than zero"),
  purpose: z.string().max(255).optional(),
  unitPriceRwf: z.coerce.number().nonnegative().optional(),
  originName: z.string().max(255).optional(),
  originLat: z.coerce.number().min(-90).max(90).optional(),
  originLng: z.coerce.number().min(-180).max(180).optional(),
  destinationName: z.string().max(255).optional(),
  destinationLat: z.coerce.number().min(-90).max(90).optional(),
  destinationLng: z.coerce.number().min(-180).max(180).optional(),
  expectedDistanceKm: z.coerce.number().nonnegative().optional(),
  estimatedFuelRequiredL: z.coerce.number().nonnegative().optional(),
  supportingNotes: z.string().max(1000).optional(),
});

export const decisionSchema = z
  .object({
    approve: z.boolean(),
    comment: z.string().max(500).optional(),
    rejectionReason: z.string().max(500).optional(),
    grantedQuantityL: z.number().positive().optional(),
  })
  .refine((data) => data.approve || !!data.rejectionReason, {
    message: "rejectionReason is required when rejecting a fuel request",
    path: ["rejectionReason"],
  });

export type CreateFuelRequestInput = z.infer<typeof createFuelRequestSchema>;
export type DecisionInput = z.infer<typeof decisionSchema>;
export type ListFuelRequestsQuery = z.infer<typeof listFuelRequestsQuerySchema>;

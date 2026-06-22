import { z } from "zod";

export const driverIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const periodQuerySchema = z.object({
  year: z.coerce.number().int().min(2000).max(2100).optional(),
  month: z.coerce.number().int().min(1).max(12).optional(),
});

export type PeriodQuery = z.infer<typeof periodQuerySchema>;

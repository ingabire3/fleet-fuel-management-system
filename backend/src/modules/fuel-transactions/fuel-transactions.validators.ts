import { z } from "zod";

const transactionTypeEnum = z.enum(["REFILL", "USAGE", "ADJUSTMENT"]);

export const transactionIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listTransactionsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  vehicleId: z.string().uuid().optional(),
  driverId: z.string().uuid().optional(),
  transactionType: transactionTypeEnum.optional(),
});

export const createTransactionSchema = z.object({
  vehicleId: z.string().uuid(),
  transactionType: transactionTypeEnum,
  quantityL: z.number(),
  unitPriceRwf: z.number().nonnegative().optional(),
  totalCostRwf: z.number().nonnegative().optional(),
  odometerKm: z.number().nonnegative().optional(),
  fuelLevelBeforeL: z.number().nonnegative().optional(),
  fuelLevelAfterL: z.number().nonnegative().optional(),
  receiptNumber: z.string().max(100).optional(),
  notes: z.string().max(500).optional(),
  recordedAt: z.coerce.date().optional(),
});

export type CreateTransactionInput = z.infer<typeof createTransactionSchema>;
export type ListTransactionsQuery = z.infer<typeof listTransactionsQuerySchema>;

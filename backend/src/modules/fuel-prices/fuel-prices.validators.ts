import { z } from "zod";

const fuelTypeEnum = z.enum(["PETROL", "DIESEL", "ELECTRIC", "HYBRID"]);

export const listFuelPricesQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  fuelType: fuelTypeEnum.optional(),
});

export const createFuelPriceSchema = z.object({
  fuelType: fuelTypeEnum,
  priceRwf: z.number().positive(),
  effectiveDate: z.coerce.date(),
});

export type CreateFuelPriceInput = z.infer<typeof createFuelPriceSchema>;
export type ListFuelPricesQuery = z.infer<typeof listFuelPricesQuerySchema>;

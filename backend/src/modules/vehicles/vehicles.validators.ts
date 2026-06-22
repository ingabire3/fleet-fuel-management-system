import { z } from "zod";
import { queryBool } from "../../lib/queryBool";

const vehicleTypeEnum = z.enum(["SEDAN", "SUV", "PICKUP", "TRUCK", "BUS", "VAN", "MOTORCYCLE", "OTHER"]);
const fuelTypeEnum = z.enum(["PETROL", "DIESEL", "ELECTRIC", "HYBRID"]);
const vehicleStatusEnum = z.enum(["ACTIVE", "MAINTENANCE", "RETIRED", "UNASSIGNED"]);

export const vehicleIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listVehiclesQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  status: vehicleStatusEnum.optional(),
  fuelType: fuelTypeEnum.optional(),
  search: z.string().min(1).max(120).optional(),
  unassigned: queryBool,
});

export const createVehicleSchema = z.object({
  plateNumber: z.string().min(1).max(30),
  make: z.string().min(1).max(60),
  model: z.string().min(1).max(60),
  year: z.number().int().min(1980).max(2100),
  vehicleType: vehicleTypeEnum,
  fuelType: fuelTypeEnum,
  tankCapacityL: z.number().positive(),
  currentFuelL: z.number().nonnegative().optional(),
  odometerKm: z.number().nonnegative().optional(),
  fuelEfficiencyKmpl: z.number().positive().optional(),
  color: z.string().max(30).optional(),
  notes: z.string().max(500).optional(),
});

export const updateVehicleSchema = z.object({
  plateNumber: z.string().min(1).max(30).optional(),
  make: z.string().min(1).max(60).optional(),
  model: z.string().min(1).max(60).optional(),
  year: z.number().int().min(1980).max(2100).optional(),
  vehicleType: vehicleTypeEnum.optional(),
  fuelType: fuelTypeEnum.optional(),
  tankCapacityL: z.number().positive().optional(),
  currentFuelL: z.number().nonnegative().optional(),
  odometerKm: z.number().nonnegative().optional(),
  fuelEfficiencyKmpl: z.number().positive().optional(),
  status: vehicleStatusEnum.optional(),
  color: z.string().max(30).nullable().optional(),
  notes: z.string().max(500).nullable().optional(),
});

export const assignDriverSchema = z.object({
  driverId: z.string().uuid().nullable(),
});

export type CreateVehicleInput = z.infer<typeof createVehicleSchema>;
export type UpdateVehicleInput = z.infer<typeof updateVehicleSchema>;
export type AssignDriverInput = z.infer<typeof assignDriverSchema>;
export type ListVehiclesQuery = z.infer<typeof listVehiclesQuerySchema>;

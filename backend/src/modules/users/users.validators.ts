import { z } from "zod";
import { queryBool } from "../../lib/queryBool";

const fuelTypeEnum = z.enum(["PETROL", "DIESEL", "ELECTRIC", "HYBRID"]);
const userRoleEnum = z.enum(["SUPER_ADMIN", "FLEET_MANAGER", "FINANCE_OFFICER", "DRIVER"]);

export const userIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  role: userRoleEnum.optional(),
  departmentId: z.string().uuid().optional(),
  isApproved: queryBool,
  isActive: queryBool,
  search: z.string().min(1).max(120).optional(),
});

export const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72),
  fullName: z.string().min(1).max(120),
  role: userRoleEnum.default("DRIVER"),
  phone: z.string().min(1).max(30).optional(),
  employeeId: z.string().min(1).max(50).optional(),
  departmentId: z.string().uuid().optional(),
  homeAddress: z.string().max(255).optional(),
  homeLat: z.number().min(-90).max(90).optional(),
  homeLng: z.number().min(-180).max(180).optional(),
  workSiteName: z.string().max(255).optional(),
  workSiteLat: z.number().min(-90).max(90).optional(),
  workSiteLng: z.number().min(-180).max(180).optional(),
  fuelType: fuelTypeEnum.optional(),
  monthlyFuelStipendRwf: z.number().nonnegative().optional(),
  monthlyBudgetRwf: z.number().nonnegative().optional(),
  workingDaysPerMonth: z.number().int().min(1).max(31).optional(),
  isApproved: z.boolean().optional(),
});

export const updateUserSchema = z.object({
  fullName: z.string().min(1).max(120).optional(),
  phone: z.string().min(1).max(30).nullable().optional(),
  employeeId: z.string().min(1).max(50).nullable().optional(),
  departmentId: z.string().uuid().nullable().optional(),
  role: userRoleEnum.optional(),
  fuelType: fuelTypeEnum.nullable().optional(),
  workingDaysPerMonth: z.number().int().min(1).max(31).optional(),
  isActive: z.boolean().optional(),
});

export const updateLocationSchema = z.object({
  homeAddress: z.string().max(255).nullable().optional(),
  homeLat: z.number().min(-90).max(90).nullable().optional(),
  homeLng: z.number().min(-180).max(180).nullable().optional(),
  workSiteName: z.string().max(255).nullable().optional(),
  workSiteLat: z.number().min(-90).max(90).nullable().optional(),
  workSiteLng: z.number().min(-180).max(180).nullable().optional(),
});

export const updateStipendSchema = z.object({
  monthlyFuelStipendRwf: z.number().nonnegative(),
  monthlyBudgetRwf: z.number().nonnegative().optional(),
  reason: z.string().max(255).optional(),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type UpdateUserInput = z.infer<typeof updateUserSchema>;
export type UpdateLocationInput = z.infer<typeof updateLocationSchema>;
export type UpdateStipendInput = z.infer<typeof updateStipendSchema>;
export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;

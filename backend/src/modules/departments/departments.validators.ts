import { z } from "zod";

export const createDepartmentSchema = z.object({
  name: z.string().min(1).max(120),
});

export const updateDepartmentSchema = z.object({
  name: z.string().min(1).max(120),
});

export const departmentIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export type CreateDepartmentInput = z.infer<typeof createDepartmentSchema>;
export type UpdateDepartmentInput = z.infer<typeof updateDepartmentSchema>;

import { prisma } from "../../config/prisma";
import { ConflictError, NotFoundError } from "../../lib/errors";
import { CreateDepartmentInput, UpdateDepartmentInput } from "./departments.validators";

export async function listDepartments(organizationId: string) {
  return prisma.department.findMany({
    where: { organizationId, deletedAt: null },
    orderBy: { name: "asc" },
  });
}

export async function getDepartmentById(organizationId: string, id: string) {
  const department = await prisma.department.findFirst({
    where: { id, organizationId, deletedAt: null },
  });
  if (!department) throw new NotFoundError("Department not found");
  return department;
}

export async function createDepartment(organizationId: string, input: CreateDepartmentInput) {
  const existing = await prisma.department.findFirst({
    where: { organizationId, name: input.name, deletedAt: null },
  });
  if (existing) throw new ConflictError("A department with this name already exists");

  return prisma.department.create({ data: { organizationId, name: input.name } });
}

export async function updateDepartment(organizationId: string, id: string, input: UpdateDepartmentInput) {
  await getDepartmentById(organizationId, id);

  const existing = await prisma.department.findFirst({
    where: { organizationId, name: input.name, deletedAt: null, NOT: { id } },
  });
  if (existing) throw new ConflictError("A department with this name already exists");

  return prisma.department.update({ where: { id }, data: { name: input.name } });
}

export async function deleteDepartment(organizationId: string, id: string) {
  await getDepartmentById(organizationId, id);
  await prisma.department.update({ where: { id }, data: { deletedAt: new Date() } });
}

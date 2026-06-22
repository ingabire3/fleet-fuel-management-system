import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as departmentsService from "./departments.service";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const departments = await departmentsService.listDepartments(req.user.organizationId);
  res.status(200).json({ data: departments });
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const department = await departmentsService.getDepartmentById(req.user.organizationId, req.params.id);
  res.status(200).json({ data: department });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const department = await departmentsService.createDepartment(req.user.organizationId, req.body);
  res.status(201).json({ data: department });
});

export const update = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const department = await departmentsService.updateDepartment(req.user.organizationId, req.params.id, req.body);
  res.status(200).json({ data: department });
});

export const remove = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await departmentsService.deleteDepartment(req.user.organizationId, req.params.id);
  res.status(204).send();
});

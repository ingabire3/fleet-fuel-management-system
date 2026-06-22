import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as vehiclesService from "./vehicles.service";
import { ListVehiclesQuery } from "./vehicles.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await vehiclesService.listVehicles(req.user, req.query as unknown as ListVehiclesQuery);
  res.status(200).json(result);
});

export const getMine = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const vehicle = await vehiclesService.getMyVehicle(req.user);
  res.status(200).json({ data: vehicle });
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const vehicle = await vehiclesService.getVehicleById(req.user, req.params.id);
  res.status(200).json({ data: vehicle });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const vehicle = await vehiclesService.createVehicle(req.user, req.body);
  res.status(201).json({ data: vehicle });
});

export const update = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const vehicle = await vehiclesService.updateVehicle(req.user, req.params.id, req.body);
  res.status(200).json({ data: vehicle });
});

export const assignDriver = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const vehicle = await vehiclesService.assignDriver(req.user, req.params.id, req.body);
  res.status(200).json({ data: vehicle });
});

export const remove = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await vehiclesService.deleteVehicle(req.user, req.params.id);
  res.status(204).send();
});

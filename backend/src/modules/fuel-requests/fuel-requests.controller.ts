import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as fuelRequestsService from "./fuel-requests.service";
import { ListFuelRequestsQuery } from "./fuel-requests.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await fuelRequestsService.listFuelRequests(req.user, req.query as unknown as ListFuelRequestsQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const request = await fuelRequestsService.getFuelRequestById(req.user, req.params.id);
  res.status(200).json({ data: request });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const request = await fuelRequestsService.createFuelRequest(req.user, req.body);
  res.status(201).json({ data: request });
});

export const fleetManagerDecision = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const request = await fuelRequestsService.fleetManagerDecision(req.user, req.params.id, req.body);
  res.status(200).json({ data: request });
});

export const financeDecision = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const request = await fuelRequestsService.financeDecision(req.user, req.params.id, req.body);
  res.status(200).json({ data: request });
});

export const cancel = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const request = await fuelRequestsService.cancelFuelRequest(req.user, req.params.id);
  res.status(200).json({ data: request });
});

import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as approvedRoutesService from "./approved-routes.service";
import { ListApprovedRoutesQuery } from "./approved-routes.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await approvedRoutesService.listApprovedRoutes(req.user, req.query as unknown as ListApprovedRoutesQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const route = await approvedRoutesService.getApprovedRouteById(req.user, req.params.id);
  res.status(200).json({ data: route });
});

export const create = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const route = await approvedRoutesService.createApprovedRoute(req.user, req.body);
  res.status(201).json({ data: route });
});

export const update = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const route = await approvedRoutesService.updateApprovedRoute(req.user, req.params.id, req.body);
  res.status(200).json({ data: route });
});

export const remove = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await approvedRoutesService.deleteApprovedRoute(req.user, req.params.id);
  res.status(204).send();
});

export const getComparison = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const comparison = await approvedRoutesService.getRouteTripComparison(req.user, req.params.id, req.params.tripId);
  res.status(200).json({ data: comparison });
});

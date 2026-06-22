import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as gpsService from "./gps-tracking.service";
import { ListTripsQuery } from "./gps-tracking.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await gpsService.listTrips(req.user, req.query as unknown as ListTripsQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const trip = await gpsService.getTripById(req.user, req.params.id);
  res.status(200).json({ data: trip });
});

export const start = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const trip = await gpsService.startTrip(req.user, req.body);
  res.status(201).json({ data: trip });
});

export const addWaypoint = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const waypoint = await gpsService.addWaypoint(req.user, req.params.id, req.body);
  res.status(201).json({ data: waypoint });
});

export const end = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const trip = await gpsService.endTrip(req.user, req.params.id, req.body);
  res.status(200).json({ data: trip });
});

export const cancel = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const trip = await gpsService.cancelTrip(req.user, req.params.id);
  res.status(200).json({ data: trip });
});

export const livePositions = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const positions = await gpsService.getLivePositions(req.user);
  res.status(200).json({ data: positions });
});

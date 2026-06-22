import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as analyticsService from "./analytics.service";
import { PeriodQuery } from "./analytics.validators";

export const driverSummary = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const summary = await analyticsService.getDriverSummary(req.user, req.params.id, req.query as unknown as PeriodQuery);
  res.status(200).json({ data: summary });
});

export const mySummary = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const summary = await analyticsService.getDriverSummary(req.user, req.user.id, req.query as unknown as PeriodQuery);
  res.status(200).json({ data: summary });
});

export const fleetSummary = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const summary = await analyticsService.getFleetSummary(req.user, req.query as unknown as PeriodQuery);
  res.status(200).json({ data: summary });
});

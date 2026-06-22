import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as alertsService from "./alerts.service";
import { ListAlertsQuery } from "./alerts.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await alertsService.listAlerts(req.user, req.query as unknown as ListAlertsQuery);
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const alert = await alertsService.getAlertById(req.user, req.params.id);
  res.status(200).json({ data: alert });
});

export const updateStatus = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const alert = await alertsService.updateAlertStatus(req.user, req.params.id, req.body);
  res.status(200).json({ data: alert });
});

import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as allocationService from "./allocation.service";
import { AllocationHistoryQuery } from "./allocation.validators";

export const getMyCurrent = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const allocation = await allocationService.getCurrentAllocation(req.user.id);
  res.status(200).json({ data: allocation });
});

export const getCurrent = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await allocationService.assertCanAccessDriverAllocation(req.user, req.params.driverId);
  const allocation = await allocationService.getCurrentAllocation(req.params.driverId);
  res.status(200).json({ data: allocation });
});

export const getHistory = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await allocationService.assertCanAccessDriverAllocation(req.user, req.params.driverId);
  const result = await allocationService.getAllocationHistory(req.params.driverId, req.query as unknown as AllocationHistoryQuery);
  res.status(200).json(result);
});

export const recompute = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  await allocationService.assertCanAccessDriverAllocation(req.user, req.params.driverId);
  const reason = req.body?.reason || "manual_recompute";
  const allocation = await allocationService.recomputeAllocationForDriver(req.params.driverId, reason, req.user.id);
  res.status(200).json({ data: allocation });
});

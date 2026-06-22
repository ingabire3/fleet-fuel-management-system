import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import { DEFAULTS } from "../../config/constants";
import * as settingsService from "./settings.service";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const settings = await settingsService.listSettings(req.user.organizationId);
  res.status(200).json({ data: settings });
});

export const update = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const key = req.params.key as keyof typeof DEFAULTS;
  const setting = await settingsService.updateSetting(req.user, key, req.body);
  res.status(200).json({ data: setting });
});

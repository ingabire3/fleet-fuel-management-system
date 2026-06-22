import { z } from "zod";
import { SETTING_KEYS } from "../../config/constants";

const settingKeyEnum = z.enum(Object.values(SETTING_KEYS) as [string, ...string[]]);

export const settingKeyParamsSchema = z.object({
  key: settingKeyEnum,
});

export const updateSettingSchema = z.object({
  value: z.string().min(1).max(255),
  description: z.string().max(255).optional(),
});

export type UpdateSettingInput = z.infer<typeof updateSettingSchema>;

import { prisma } from "../config/prisma";
import { DEFAULTS } from "../config/constants";

type SettingKey = keyof typeof DEFAULTS;

/**
 * Reads a system setting for `organizationId`, falling back to the global
 * (organizationId = null) override, then to the hardcoded DEFAULTS.
 */
export async function getSetting(organizationId: string, key: SettingKey): Promise<string> {
  const orgSetting = await prisma.systemSetting.findUnique({
    where: { organizationId_key: { organizationId, key } },
  });
  if (orgSetting) return orgSetting.value;

  const globalSetting = await prisma.systemSetting.findFirst({
    where: { organizationId: null, key },
  });
  if (globalSetting) return globalSetting.value;

  return String(DEFAULTS[key]);
}

export async function getNumericSetting(organizationId: string, key: SettingKey): Promise<number> {
  const value = await getSetting(organizationId, key);
  return Number(value);
}

export async function getBooleanSetting(organizationId: string, key: SettingKey): Promise<boolean> {
  const value = await getSetting(organizationId, key);
  return value === "true";
}

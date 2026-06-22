import { UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { DEFAULTS, SETTING_KEYS } from "../../config/constants";
import { getSetting } from "../../lib/settings";
import { AuthenticatedUser } from "../../types/auth";
import { recomputeAllocationForDriver } from "../fuel-allocation/allocation.hooks";
import { UpdateSettingInput } from "./settings.validators";

type SettingKey = keyof typeof DEFAULTS;

/** Setting keys that feed the fuel allocation formula - changing these requires recomputing every driver's allocation. */
const ALLOCATION_SETTING_KEYS: SettingKey[] = ["FUEL_BUFFER_PERCENT", "DEFAULT_WORKING_DAYS", "ROAD_DISTANCE_FACTOR"];

export async function listSettings(organizationId: string) {
  const keys = Object.values(SETTING_KEYS) as SettingKey[];

  return Promise.all(
    keys.map(async (key) => ({
      key,
      value: await getSetting(organizationId, key),
      default: String(DEFAULTS[key]),
    }))
  );
}

export async function updateSetting(actor: AuthenticatedUser, key: SettingKey, input: UpdateSettingInput) {
  const setting = await prisma.systemSetting.upsert({
    where: { organizationId_key: { organizationId: actor.organizationId, key } },
    update: { value: input.value, description: input.description, changedById: actor.id },
    create: {
      organizationId: actor.organizationId,
      key,
      value: input.value,
      description: input.description,
      changedById: actor.id,
    },
  });

  if (ALLOCATION_SETTING_KEYS.includes(key)) {
    const drivers = await prisma.user.findMany({
      where: { organizationId: actor.organizationId, role: UserRole.DRIVER, deletedAt: null },
      select: { id: true },
    });

    for (const driver of drivers) {
      await recomputeAllocationForDriver(driver.id, `setting_changed:${key}`, actor.id);
    }
  }

  return setting;
}

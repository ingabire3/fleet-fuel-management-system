import { UserRole } from "@prisma/client";
import { logger } from "../config/logger";
import { prisma } from "../config/prisma";
import { recomputeAllocationForDriver } from "../modules/fuel-allocation/allocation.hooks";

/** Recomputes the fuel allocation for every active driver, starting a new monthly period. */
export async function runMonthlyAllocationJob(): Promise<void> {
  const drivers = await prisma.user.findMany({
    where: { role: UserRole.DRIVER, deletedAt: null, isActive: true },
    select: { id: true },
  });

  logger.info({ driverCount: drivers.length }, "Running monthly allocation recompute");

  for (const driver of drivers) {
    await recomputeAllocationForDriver(driver.id, "monthly_recompute").catch((err) =>
      logger.error({ err, driverId: driver.id }, "Monthly allocation recompute failed")
    );
  }
}

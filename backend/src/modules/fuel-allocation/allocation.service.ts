import { FuelAllocation, FuelRequestStatus, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { logger } from "../../config/logger";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination, PaginationQuery } from "../../lib/pagination";
import { getNumericSetting } from "../../lib/settings";
import { currentPeriod } from "../../lib/time";
import { AuthenticatedUser } from "../../types/auth";
import { emit } from "../notifications/notification-dispatcher";
import { computeAllocation } from "./allocation.engine";

/** Ensures the actor may view/recompute the given driver's allocation: drivers may only access their own, staff may access any driver in their org. */
export async function assertCanAccessDriverAllocation(actor: AuthenticatedUser, driverId: string): Promise<void> {
  if (actor.role === UserRole.DRIVER) {
    if (actor.id !== driverId) throw new ForbiddenError("You can only access your own fuel allocation");
    return;
  }

  const driver = await prisma.user.findFirst({
    where: { id: driverId, organizationId: actor.organizationId, role: UserRole.DRIVER, deletedAt: null },
    select: { id: true },
  });
  if (!driver) throw new NotFoundError("Driver not found");
}

/**
 * Recomputes a driver's fuel allocation for the current period and appends a new
 * `FuelAllocation` snapshot row. Returns `null` (without writing a row) if the
 * driver is missing required inputs (assigned vehicle, home/work coordinates,
 * or a fuel price for the vehicle's fuel type) - this is expected for newly
 * registered drivers and is not treated as an error.
 */
export async function recomputeAllocationForDriver(
  driverId: string,
  reason: string,
  triggeredById?: string
): Promise<FuelAllocation | null> {
  const driver = await prisma.user.findUnique({
    where: { id: driverId },
    include: { assignedVehicle: true },
  });

  if (!driver || driver.role !== UserRole.DRIVER || driver.deletedAt) {
    return null;
  }

  const vehicle = driver.assignedVehicle;
  if (!vehicle || vehicle.deletedAt) {
    logger.debug({ driverId, reason }, "Skipping allocation recompute: no vehicle assigned");
    return null;
  }

  if (driver.homeLat === null || driver.homeLng === null || driver.workSiteLat === null || driver.workSiteLng === null) {
    logger.debug({ driverId, reason }, "Skipping allocation recompute: home/work location not set");
    return null;
  }

  const fuelPrice = await prisma.fuelPrice.findFirst({
    where: { organizationId: driver.organizationId, fuelType: vehicle.fuelType, effectiveDate: { lte: new Date() } },
    orderBy: { effectiveDate: "desc" },
  });
  if (!fuelPrice) {
    logger.debug({ driverId, reason, fuelType: vehicle.fuelType }, "Skipping allocation recompute: no fuel price configured");
    return null;
  }

  const roadDistanceFactor = await getNumericSetting(driver.organizationId, "ROAD_DISTANCE_FACTOR");
  const bufferPercent = await getNumericSetting(driver.organizationId, "FUEL_BUFFER_PERCENT");
  const workingDays = driver.workingDaysPerMonth || (await getNumericSetting(driver.organizationId, "DEFAULT_WORKING_DAYS"));

  const { year, month } = currentPeriod();
  const extraFuelGrantedL = await sumApprovedExtraFuel(driverId, year, month);

  const result = computeAllocation({
    home: { lat: driver.homeLat.toNumber(), lng: driver.homeLng.toNumber() },
    work: { lat: driver.workSiteLat.toNumber(), lng: driver.workSiteLng.toNumber() },
    workingDays,
    vehicleEfficiencyKmpl: vehicle.fuelEfficiencyKmpl.toNumber(),
    roadDistanceFactor,
    bufferPercent,
    fuelPriceRwf: fuelPrice.priceRwf.toNumber(),
    extraFuelGrantedL,
  });

  const allocation = await prisma.fuelAllocation.create({
    data: {
      driverId: driver.id,
      vehicleId: vehicle.id,
      periodYear: year,
      periodMonth: month,
      distanceKm: result.distanceKm,
      workingDays,
      vehicleEfficiency: vehicle.fuelEfficiencyKmpl,
      fuelPriceRwf: fuelPrice.priceRwf,
      bufferPercent,
      baseRequirementL: result.baseRequirementL,
      bufferL: result.bufferL,
      finalAllocationL: result.finalAllocationL,
      extraFuelGrantedL,
      totalAvailableL: result.totalAvailableL,
      projectedCostRwf: result.projectedCostRwf,
      recomputeReason: reason,
      triggeredById,
    },
  });

  await emit("allocation_recomputed", [driver.id], {
    finalAllocationL: allocation.finalAllocationL.toFixed(2),
    reason,
  });

  return allocation;
}

export async function getCurrentAllocation(driverId: string): Promise<FuelAllocation | null> {
  return prisma.fuelAllocation.findFirst({
    where: { driverId },
    orderBy: { createdAt: "desc" },
  });
}

export async function getAllocationHistory(driverId: string, query: PaginationQuery) {
  const pagination = parsePagination(query);

  const [data, total] = await Promise.all([
    prisma.fuelAllocation.findMany({
      where: { driverId },
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.fuelAllocation.count({ where: { driverId } }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

async function sumApprovedExtraFuel(driverId: string, year: number, month: number): Promise<number> {
  const periodStart = new Date(Date.UTC(year, month - 1, 1));
  const periodEnd = new Date(Date.UTC(year, month, 1));

  const result = await prisma.fuelRequest.aggregate({
    where: {
      driverId,
      status: FuelRequestStatus.FINANCE_APPROVED,
      createdAt: { gte: periodStart, lt: periodEnd },
    },
    _sum: { grantedQuantityL: true },
  });

  return result._sum.grantedQuantityL?.toNumber() ?? 0;
}

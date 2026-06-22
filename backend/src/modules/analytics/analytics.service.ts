import { AlertStatus, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { currentPeriod } from "../../lib/time";
import { AuthenticatedUser } from "../../types/auth";
import { assertCanAccessDriverAllocation, getCurrentAllocation } from "../fuel-allocation/allocation.service";
import { PeriodQuery } from "./analytics.validators";

function resolvePeriod(query: PeriodQuery) {
  const fallback = currentPeriod();
  const year = query.year ?? fallback.year;
  const month = query.month ?? fallback.month;
  return {
    year,
    month,
    start: new Date(Date.UTC(year, month - 1, 1)),
    end: new Date(Date.UTC(year, month, 1)),
  };
}

export async function getDriverSummary(actor: AuthenticatedUser, driverId: string, query: PeriodQuery) {
  await assertCanAccessDriverAllocation(actor, driverId);

  const driver = await prisma.user.findUnique({
    where: { id: driverId },
    select: {
      id: true,
      fullName: true,
      email: true,
      fuelType: true,
      monthlyFuelStipendRwf: true,
      monthlyBudgetRwf: true,
      assignedVehicle: {
        select: { id: true, plateNumber: true, fuelEfficiencyKmpl: true, currentFuelL: true, tankCapacityL: true },
      },
    },
  });
  if (!driver) throw new NotFoundError("Driver not found");

  const { year, month, start, end } = resolvePeriod(query);

  const [allocation, transactionTotals, requestCounts, tripStats, detourCount, openAlerts] = await Promise.all([
    getCurrentAllocation(driverId),
    prisma.fuelTransaction.groupBy({
      by: ["transactionType"],
      where: { driverId, recordedAt: { gte: start, lt: end } },
      _sum: { quantityL: true, totalCostRwf: true },
    }),
    prisma.fuelRequest.groupBy({
      by: ["status"],
      where: { driverId, createdAt: { gte: start, lt: end } },
      _count: true,
    }),
    prisma.gpsTrip.aggregate({
      where: { driverId, createdAt: { gte: start, lt: end } },
      _count: true,
      _sum: { distanceKm: true },
    }),
    prisma.gpsTrip.count({ where: { driverId, createdAt: { gte: start, lt: end }, isDetourFlagged: true } }),
    prisma.alert.count({ where: { driverId, status: AlertStatus.OPEN } }),
  ]);

  return {
    driver,
    period: { year, month },
    allocation,
    fuelTransactions: transactionTotals.map((t) => ({
      transactionType: t.transactionType,
      totalQuantityL: t._sum.quantityL?.toNumber() ?? 0,
      totalCostRwf: t._sum.totalCostRwf?.toNumber() ?? 0,
    })),
    fuelRequests: requestCounts.map((r) => ({ status: r.status, count: r._count })),
    trips: {
      count: tripStats._count,
      totalDistanceKm: tripStats._sum.distanceKm?.toNumber() ?? 0,
      detourCount,
    },
    openAlerts,
  };
}

interface MonthlyTrendRow {
  month: Date;
  totalQuantityL: number;
  totalCostRwf: number;
}

async function getFuelUsageByDepartment(organizationId: string, start: Date, end: Date) {
  const transactions = await prisma.fuelTransaction.findMany({
    where: { vehicle: { organizationId }, recordedAt: { gte: start, lt: end } },
    select: {
      quantityL: true,
      totalCostRwf: true,
      driver: { select: { departmentId: true, department: { select: { name: true } } } },
    },
  });

  const byDepartment = new Map<string, { departmentId: string | null; departmentName: string; totalQuantityL: number; totalCostRwf: number }>();
  for (const tx of transactions) {
    const departmentId = tx.driver.departmentId;
    const key = departmentId ?? "unassigned";
    const entry = byDepartment.get(key) ?? {
      departmentId,
      departmentName: tx.driver.department?.name ?? "Unassigned",
      totalQuantityL: 0,
      totalCostRwf: 0,
    };
    entry.totalQuantityL += tx.quantityL.toNumber();
    entry.totalCostRwf += tx.totalCostRwf?.toNumber() ?? 0;
    byDepartment.set(key, entry);
  }

  return Array.from(byDepartment.values());
}

async function getVehicleEfficiency(organizationId: string, start: Date, end: Date) {
  const [vehicles, tripStats] = await Promise.all([
    prisma.vehicle.findMany({
      where: { organizationId, deletedAt: null },
      select: { id: true, plateNumber: true, fuelEfficiencyKmpl: true },
    }),
    prisma.gpsTrip.groupBy({
      by: ["vehicleId"],
      where: { vehicle: { organizationId }, createdAt: { gte: start, lt: end }, status: "COMPLETED" },
      _sum: { distanceKm: true, fuelConsumedL: true },
    }),
  ]);

  const statsByVehicle = new Map(tripStats.map((s) => [s.vehicleId, s._sum]));

  return vehicles.map((v) => {
    const stats = statsByVehicle.get(v.id);
    const distanceKm = stats?.distanceKm?.toNumber() ?? 0;
    const fuelConsumedL = stats?.fuelConsumedL?.toNumber() ?? 0;
    return {
      vehicleId: v.id,
      plateNumber: v.plateNumber,
      ratedEfficiencyKmpl: v.fuelEfficiencyKmpl.toNumber(),
      actualEfficiencyKmpl: fuelConsumedL > 0 ? Math.round((distanceKm / fuelConsumedL) * 100) / 100 : null,
      distanceKm,
      fuelConsumedL,
    };
  });
}

/** Last 6 months (including the requested period) of fleet-wide fuel quantity/cost, for trend charts. */
async function getMonthlyTrends(organizationId: string, year: number, month: number) {
  const rangeStart = new Date(Date.UTC(year, month - 6, 1));
  const rangeEnd = new Date(Date.UTC(year, month, 1));

  const rows = await prisma.$queryRaw<MonthlyTrendRow[]>`
    SELECT date_trunc('month', ft."recordedAt") as month,
           COALESCE(SUM(ft."quantityL"), 0)::float8 as "totalQuantityL",
           COALESCE(SUM(ft."totalCostRwf"), 0)::float8 as "totalCostRwf"
    FROM "fuel_transactions" ft
    JOIN "vehicles" v ON v.id = ft."vehicleId"
    WHERE v."organizationId" = ${organizationId}
      AND ft."recordedAt" >= ${rangeStart}
      AND ft."recordedAt" < ${rangeEnd}
    GROUP BY month
    ORDER BY month
  `;

  return rows.map((row) => ({
    period: { year: row.month.getUTCFullYear(), month: row.month.getUTCMonth() + 1 },
    totalQuantityL: Number(row.totalQuantityL),
    totalCostRwf: Number(row.totalCostRwf),
  }));
}

export async function getFleetSummary(actor: AuthenticatedUser, query: PeriodQuery) {
  if (actor.role === UserRole.DRIVER) {
    throw new ForbiddenError("Drivers cannot access fleet analytics");
  }

  const { year, month, start, end } = resolvePeriod(query);

  const [
    vehicleCounts,
    driverCount,
    latestAllocations,
    transactionTotals,
    requestCounts,
    openAlertsBySeverity,
    fuelUsageByDepartment,
    vehicleEfficiency,
    monthlyTrends,
    allDrivers,
    consumedByDriver,
  ] = await Promise.all([
    prisma.vehicle.groupBy({
      by: ["status"],
      where: { organizationId: actor.organizationId, deletedAt: null },
      _count: true,
    }),
    prisma.user.count({
      where: { organizationId: actor.organizationId, role: UserRole.DRIVER, deletedAt: null, isActive: true },
    }),
    prisma.fuelAllocation.findMany({
      where: { driver: { organizationId: actor.organizationId, deletedAt: null } },
      distinct: ["driverId"],
      orderBy: [{ driverId: "asc" }, { createdAt: "desc" }],
    }),
    prisma.fuelTransaction.groupBy({
      by: ["transactionType"],
      where: { vehicle: { organizationId: actor.organizationId }, recordedAt: { gte: start, lt: end } },
      _sum: { quantityL: true, totalCostRwf: true },
    }),
    prisma.fuelRequest.groupBy({
      by: ["status"],
      where: { driver: { organizationId: actor.organizationId }, createdAt: { gte: start, lt: end } },
      _count: true,
    }),
    prisma.alert.groupBy({
      by: ["severity"],
      where: {
        status: AlertStatus.OPEN,
        OR: [{ driver: { organizationId: actor.organizationId } }, { vehicle: { organizationId: actor.organizationId } }],
      },
      _count: true,
    }),
    getFuelUsageByDepartment(actor.organizationId, start, end),
    getVehicleEfficiency(actor.organizationId, start, end),
    getMonthlyTrends(actor.organizationId, year, month),
    prisma.user.findMany({
      where: { organizationId: actor.organizationId, role: UserRole.DRIVER, deletedAt: null },
      select: {
        id: true,
        fullName: true,
        monthlyBudgetRwf: true,
        assignedVehicle: { select: { plateNumber: true } },
      },
      orderBy: { fullName: "asc" },
    }),
    prisma.fuelTransaction.groupBy({
      by: ["driverId"],
      where: { driver: { organizationId: actor.organizationId }, recordedAt: { gte: start, lt: end } },
      _sum: { quantityL: true, totalCostRwf: true },
    }),
  ]);

  const allocationTotals = latestAllocations.reduce(
    (acc, a) => ({
      finalAllocationL: acc.finalAllocationL + a.finalAllocationL.toNumber(),
      totalAvailableL: acc.totalAvailableL + a.totalAvailableL.toNumber(),
      projectedCostRwf: acc.projectedCostRwf + a.projectedCostRwf.toNumber(),
    }),
    { finalAllocationL: 0, totalAvailableL: 0, projectedCostRwf: 0 }
  );

  const allocationByDriver = new Map(latestAllocations.map((a) => [a.driverId, a]));
  const consumedMap = new Map(consumedByDriver.map((r) => [r.driverId, r._sum]));

  const driverBreakdown = allDrivers.map((d) => {
    const alloc = allocationByDriver.get(d.id);
    const consumed = consumedMap.get(d.id);
    const consumedL = consumed?.quantityL?.toNumber() ?? 0;
    const consumedCostRwf = consumed?.totalCostRwf?.toNumber() ?? 0;
    const totalAvailableL = alloc?.totalAvailableL?.toNumber() ?? 0;
    return {
      driverId: d.id,
      driverName: d.fullName,
      vehiclePlate: d.assignedVehicle?.plateNumber ?? null,
      monthlyBudgetRwf: d.monthlyBudgetRwf?.toNumber() ?? 0,
      allocation: alloc
        ? {
            distanceKm: alloc.distanceKm.toNumber(),
            workingDays: alloc.workingDays,
            baseRequirementL: alloc.baseRequirementL.toNumber(),
            bufferL: alloc.bufferL.toNumber(),
            bufferPercent: alloc.bufferPercent.toNumber(),
            extraFuelGrantedL: alloc.extraFuelGrantedL.toNumber(),
            finalAllocationL: alloc.finalAllocationL.toNumber(),
            totalAvailableL,
            projectedCostRwf: alloc.projectedCostRwf.toNumber(),
            fuelPriceRwf: alloc.fuelPriceRwf.toNumber(),
          }
        : null,
      consumedL,
      consumedCostRwf,
      percentConsumed: totalAvailableL > 0 ? (consumedL / totalAvailableL) * 100 : 0,
    };
  });

  return {
    period: { year, month },
    vehicles: vehicleCounts.map((v) => ({ status: v.status, count: v._count })),
    driverCount,
    allocationTotals,
    fuelTransactions: transactionTotals.map((t) => ({
      transactionType: t.transactionType,
      totalQuantityL: t._sum.quantityL?.toNumber() ?? 0,
      totalCostRwf: t._sum.totalCostRwf?.toNumber() ?? 0,
    })),
    fuelRequests: requestCounts.map((r) => ({ status: r.status, count: r._count })),
    openAlerts: openAlertsBySeverity.map((a) => ({ severity: a.severity, count: a._count })),
    fuelUsageByDepartment,
    vehicleEfficiency,
    monthlyTrends,
    driverBreakdown,
  };
}

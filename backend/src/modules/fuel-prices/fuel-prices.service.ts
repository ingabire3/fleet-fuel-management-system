import { FuelType, Prisma, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ConflictError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { recomputeAllocationForDriver } from "../fuel-allocation/allocation.hooks";
import { CreateFuelPriceInput, ListFuelPricesQuery } from "./fuel-prices.validators";

export async function listFuelPrices(actor: AuthenticatedUser, query: ListFuelPricesQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.FuelPriceWhereInput = {
    organizationId: actor.organizationId,
  };
  if (query.fuelType) where.fuelType = query.fuelType;

  const [data, total] = await Promise.all([
    prisma.fuelPrice.findMany({
      where,
      orderBy: { effectiveDate: "desc" },
      skip: pagination.skip,
      take: pagination.take,
      include: { setBy: { select: { id: true, fullName: true } } },
    }),
    prisma.fuelPrice.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

/** Returns the most recent fuel price effective on or before `asOf` (defaults to now). */
export async function getCurrentFuelPrice(organizationId: string, fuelType: FuelType, asOf: Date = new Date()) {
  return prisma.fuelPrice.findFirst({
    where: { organizationId, fuelType, effectiveDate: { lte: asOf } },
    orderBy: { effectiveDate: "desc" },
  });
}

export async function createFuelPrice(actor: AuthenticatedUser, input: CreateFuelPriceInput) {
  const existing = await prisma.fuelPrice.findUnique({
    where: {
      organizationId_fuelType_effectiveDate: {
        organizationId: actor.organizationId,
        fuelType: input.fuelType,
        effectiveDate: input.effectiveDate,
      },
    },
  });
  if (existing) throw new ConflictError("A price for this fuel type and effective date already exists");

  const fuelPrice = await prisma.fuelPrice.create({
    data: {
      organizationId: actor.organizationId,
      fuelType: input.fuelType,
      priceRwf: input.priceRwf,
      effectiveDate: input.effectiveDate,
      setById: actor.id,
    },
  });

  const affectedDrivers = await prisma.user.findMany({
    where: {
      organizationId: actor.organizationId,
      role: UserRole.DRIVER,
      deletedAt: null,
      assignedVehicle: { fuelType: input.fuelType, deletedAt: null },
    },
    select: { id: true },
  });

  for (const driver of affectedDrivers) {
    await recomputeAllocationForDriver(driver.id, "fuel_price_changed", actor.id);
  }

  return fuelPrice;
}

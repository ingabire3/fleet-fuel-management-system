import { Prisma, TransactionType, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { CreateTransactionInput, ListTransactionsQuery } from "./fuel-transactions.validators";

const TRANSACTION_INCLUDE = {
  vehicle: { select: { id: true, plateNumber: true, make: true, model: true } },
  driver: { select: { id: true, fullName: true } },
} satisfies Prisma.FuelTransactionInclude;

export async function listTransactions(actor: AuthenticatedUser, query: ListTransactionsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.FuelTransactionWhereInput = {
    vehicle: { organizationId: actor.organizationId },
  };

  if (actor.role === UserRole.DRIVER) {
    where.driverId = actor.id;
  } else if (query.driverId) {
    where.driverId = query.driverId;
  }

  if (query.vehicleId) where.vehicleId = query.vehicleId;
  if (query.transactionType) where.transactionType = query.transactionType;

  const [data, total] = await Promise.all([
    prisma.fuelTransaction.findMany({
      where,
      include: TRANSACTION_INCLUDE,
      orderBy: { recordedAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.fuelTransaction.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getTransactionById(actor: AuthenticatedUser, id: string) {
  const transaction = await prisma.fuelTransaction.findFirst({
    where: { id, vehicle: { organizationId: actor.organizationId } },
    include: TRANSACTION_INCLUDE,
  });
  if (!transaction) throw new NotFoundError("Fuel transaction not found");

  if (actor.role === UserRole.DRIVER && transaction.driverId !== actor.id) {
    throw new ForbiddenError("You can only access your own fuel transactions");
  }

  return transaction;
}

export async function createTransaction(actor: AuthenticatedUser, input: CreateTransactionInput) {
  const vehicle = await prisma.vehicle.findFirst({
    where: { id: input.vehicleId, organizationId: actor.organizationId, deletedAt: null },
  });
  if (!vehicle) throw new NotFoundError("Vehicle not found");
  if (!vehicle.assignedDriverId) throw new ForbiddenError("Vehicle has no assigned driver");

  const totalCostRwf =
    input.totalCostRwf ?? (input.unitPriceRwf !== undefined ? input.unitPriceRwf * input.quantityL : undefined);

  const currentFuelL = vehicle.currentFuelL.toNumber();
  const tankCapacityL = vehicle.tankCapacityL.toNumber();

  let newFuelLevelL: number;
  if (input.fuelLevelAfterL !== undefined) {
    newFuelLevelL = input.fuelLevelAfterL;
  } else if (input.transactionType === TransactionType.USAGE) {
    newFuelLevelL = currentFuelL - input.quantityL;
  } else {
    newFuelLevelL = currentFuelL + input.quantityL;
  }
  newFuelLevelL = Math.min(Math.max(newFuelLevelL, 0), tankCapacityL);

  const [transaction] = await prisma.$transaction([
    prisma.fuelTransaction.create({
      data: {
        vehicleId: vehicle.id,
        driverId: vehicle.assignedDriverId,
        transactionType: input.transactionType,
        quantityL: input.quantityL,
        unitPriceRwf: input.unitPriceRwf,
        totalCostRwf,
        odometerKm: input.odometerKm,
        fuelLevelBeforeL: input.fuelLevelBeforeL ?? currentFuelL,
        fuelLevelAfterL: newFuelLevelL,
        receiptNumber: input.receiptNumber,
        notes: input.notes,
        recordedAt: input.recordedAt,
      },
      include: TRANSACTION_INCLUDE,
    }),
    prisma.vehicle.update({
      where: { id: vehicle.id },
      data: {
        currentFuelL: newFuelLevelL,
        odometerKm: input.odometerKm !== undefined && input.odometerKm > vehicle.odometerKm.toNumber() ? input.odometerKm : undefined,
      },
    }),
  ]);

  return transaction;
}

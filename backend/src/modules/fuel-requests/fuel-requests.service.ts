import { AlertSeverity, AlertType, FuelRequestStatus, Prisma, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { recomputeAllocationForDriver } from "../fuel-allocation/allocation.hooks";
import { emit } from "../notifications/notification-dispatcher";
import { CreateFuelRequestInput, DecisionInput, ListFuelRequestsQuery } from "./fuel-requests.validators";
import { assertTransition } from "./fuel-requests.state-machine";

const REQUEST_INCLUDE = {
  driver: { select: { id: true, fullName: true, organizationId: true, monthlyBudgetRwf: true } },
  vehicle: { select: { id: true, plateNumber: true, fuelType: true } },
} satisfies Prisma.FuelRequestInclude;

export async function listFuelRequests(actor: AuthenticatedUser, query: ListFuelRequestsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.FuelRequestWhereInput = {
    driver: { organizationId: actor.organizationId },
  };

  if (actor.role === UserRole.DRIVER) {
    where.driverId = actor.id;
  } else if (query.driverId) {
    where.driverId = query.driverId;
  }

  if (query.status) where.status = query.status;

  const [data, total] = await Promise.all([
    prisma.fuelRequest.findMany({
      where,
      include: REQUEST_INCLUDE,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.fuelRequest.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getFuelRequestById(actor: AuthenticatedUser, id: string) {
  const request = await loadRequest(actor, id);
  return request;
}

export async function createFuelRequest(actor: AuthenticatedUser, input: CreateFuelRequestInput) {
  if (actor.role !== UserRole.DRIVER) {
    throw new ForbiddenError("Only drivers can submit extra fuel requests");
  }

  const driver = await prisma.user.findUnique({ where: { id: actor.id }, select: { fullName: true } });
  if (!driver) throw new NotFoundError("Driver not found");

  const vehicle = await prisma.vehicle.findFirst({
    where: { assignedDriverId: actor.id, organizationId: actor.organizationId, deletedAt: null },
  });
  if (!vehicle) throw new ForbiddenError("You do not have a vehicle assigned");

  const request = await prisma.fuelRequest.create({
    data: {
      vehicleId: vehicle.id,
      driverId: actor.id,
      requestedQuantityL: input.requestedQuantityL,
      purpose: input.purpose,
      unitPriceRwf: input.unitPriceRwf,
      originName: input.originName,
      originLat: input.originLat,
      originLng: input.originLng,
      destinationName: input.destinationName,
      destinationLat: input.destinationLat,
      destinationLng: input.destinationLng,
      expectedDistanceKm: input.expectedDistanceKm,
      estimatedFuelRequiredL: input.estimatedFuelRequiredL,
      supportingNotes: input.supportingNotes,
    },
    include: REQUEST_INCLUDE,
  });

  const recipients = await getStaffIds(actor.organizationId, [UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER]);
  await emit("fuel_request_submitted", recipients, {
    driverName: driver.fullName,
    quantityL: request.requestedQuantityL.toNumber(),
  });

  return request;
}

export async function fleetManagerDecision(actor: AuthenticatedUser, id: string, input: DecisionInput) {
  const request = await loadRequest(actor, id);

  const toStatus = input.approve ? FuelRequestStatus.FLEET_MANAGER_APPROVED : FuelRequestStatus.FLEET_MANAGER_REJECTED;
  assertTransition(request.status, toStatus);

  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.fuelRequest.update({
      where: { id: request.id },
      data: {
        status: toStatus,
        ...(input.approve
          ? {}
          : { finalDecisionById: actor.id, finalDecisionAt: new Date(), rejectionReason: input.rejectionReason }),
      },
      include: REQUEST_INCLUDE,
    });

    await tx.fuelRequestApproval.create({
      data: {
        fuelRequestId: request.id,
        actorId: actor.id,
        fromStatus: request.status,
        toStatus,
        comment: input.comment ?? input.rejectionReason,
      },
    });

    return result;
  });

  if (input.approve) {
    const recipients = await getStaffIds(actor.organizationId, [UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER]);
    await emit("fuel_request_fm_approved", recipients, {
      driverName: updated.driver.fullName,
      quantityL: updated.requestedQuantityL.toNumber(),
    });
  } else {
    await emit("fuel_request_rejected", [updated.driverId], { reason: input.rejectionReason });
  }

  return updated;
}

export async function financeDecision(actor: AuthenticatedUser, id: string, input: DecisionInput) {
  const request = await loadRequest(actor, id);

  const toStatus = input.approve ? FuelRequestStatus.FINANCE_APPROVED : FuelRequestStatus.FINANCE_REJECTED;
  assertTransition(request.status, toStatus);

  const grantedQuantityL = input.grantedQuantityL ?? request.requestedQuantityL.toNumber();

  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.fuelRequest.update({
      where: { id: request.id },
      data: {
        status: toStatus,
        finalDecisionById: actor.id,
        finalDecisionAt: new Date(),
        rejectionReason: input.approve ? undefined : input.rejectionReason,
        grantedQuantityL: input.approve ? grantedQuantityL : undefined,
      },
      include: REQUEST_INCLUDE,
    });

    await tx.fuelRequestApproval.create({
      data: {
        fuelRequestId: request.id,
        actorId: actor.id,
        fromStatus: request.status,
        toStatus,
        comment: input.comment ?? input.rejectionReason,
      },
    });

    return result;
  });

  if (input.approve) {
    await emit("fuel_request_approved", [updated.driverId], { quantityL: grantedQuantityL });

    const allocation = await recomputeAllocationForDriver(updated.driverId, "extra_grant", actor.id);

    const monthlyBudgetRwf = updated.driver.monthlyBudgetRwf.toNumber();
    if (allocation && monthlyBudgetRwf > 0) {
      const projectedCostRwf = allocation.projectedCostRwf.toNumber();
      if (projectedCostRwf > monthlyBudgetRwf) {
        const percentUsed = Math.round((projectedCostRwf / monthlyBudgetRwf) * 100);

        await prisma.alert.create({
          data: {
            driverId: updated.driverId,
            vehicleId: updated.vehicleId,
            fuelRequestId: updated.id,
            alertType: AlertType.BUDGET_EXCEEDED,
            severity: AlertSeverity.HIGH,
            title: "Monthly fuel budget exceeded",
            description: `Projected fuel cost of ${projectedCostRwf.toFixed(2)} RWF exceeds the monthly budget of ${monthlyBudgetRwf.toFixed(2)} RWF.`,
          },
        });

        const recipients = await getStaffIds(actor.organizationId, [
          UserRole.SUPER_ADMIN,
          UserRole.FLEET_MANAGER,
          UserRole.FINANCE_OFFICER,
        ]);
        await emit("budget_exceeded", recipients, { driverName: updated.driver.fullName, percentUsed });
      }
    }
  } else {
    await emit("fuel_request_rejected", [updated.driverId], { reason: input.rejectionReason });
  }

  return updated;
}

export async function cancelFuelRequest(actor: AuthenticatedUser, id: string) {
  const request = await loadRequest(actor, id);

  if (actor.role !== UserRole.DRIVER || request.driverId !== actor.id) {
    throw new ForbiddenError("You can only cancel your own fuel requests");
  }

  assertTransition(request.status, FuelRequestStatus.CANCELLED);

  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.fuelRequest.update({
      where: { id: request.id },
      data: { status: FuelRequestStatus.CANCELLED },
      include: REQUEST_INCLUDE,
    });

    await tx.fuelRequestApproval.create({
      data: {
        fuelRequestId: request.id,
        actorId: actor.id,
        fromStatus: request.status,
        toStatus: FuelRequestStatus.CANCELLED,
      },
    });

    return result;
  });

  const recipients = await getStaffIds(actor.organizationId, [
    UserRole.SUPER_ADMIN,
    UserRole.FLEET_MANAGER,
    UserRole.FINANCE_OFFICER,
  ]);
  await emit("fuel_request_cancelled", recipients, { driverName: updated.driver.fullName });

  return updated;
}

async function loadRequest(actor: AuthenticatedUser, id: string) {
  const request = await prisma.fuelRequest.findFirst({
    where: { id, driver: { organizationId: actor.organizationId } },
    include: REQUEST_INCLUDE,
  });
  if (!request) throw new NotFoundError("Fuel request not found");

  if (actor.role === UserRole.DRIVER && request.driverId !== actor.id) {
    throw new ForbiddenError("You can only access your own fuel requests");
  }

  return request;
}

async function getStaffIds(organizationId: string, roles: UserRole[]): Promise<string[]> {
  const staff = await prisma.user.findMany({
    where: { organizationId, role: { in: roles }, deletedAt: null, isActive: true },
    select: { id: true },
  });
  return staff.map((u) => u.id);
}

import { PermissionType, Prisma, UserRole, VehicleStatus } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ConflictError, ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { recomputeAllocationForDriver } from "../fuel-allocation/allocation.hooks";
import { emit } from "../notifications/notification-dispatcher";
import { hasPermission } from "../users/permissions.service";
import { AssignDriverInput, CreateVehicleInput, ListVehiclesQuery, UpdateVehicleInput } from "./vehicles.validators";

export async function listVehicles(actor: AuthenticatedUser, query: ListVehiclesQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.VehicleWhereInput = {
    organizationId: actor.organizationId,
    deletedAt: null,
  };

  // Drivers see only their assigned vehicle
  if (actor.role === UserRole.DRIVER) {
    where.assignedDriverId = actor.id;
  } else {
    if (query.status) where.status = query.status;
    if (query.fuelType) where.fuelType = query.fuelType;
    if (query.unassigned) where.assignedDriverId = null;
  }

  if (query.search) {
    where.OR = [
      { plateNumber: { contains: query.search, mode: "insensitive" } },
      { make: { contains: query.search, mode: "insensitive" } },
      { model: { contains: query.search, mode: "insensitive" } },
    ];
  }

  const [data, total] = await Promise.all([
    prisma.vehicle.findMany({
      where,
      include: { assignedDriver: { select: { id: true, fullName: true, email: true } } },
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.vehicle.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getVehicleById(actor: AuthenticatedUser, id: string) {
  const vehicle = await prisma.vehicle.findFirst({
    where: { id, organizationId: actor.organizationId, deletedAt: null },
    include: { assignedDriver: { select: { id: true, fullName: true, email: true } } },
  });
  if (!vehicle) throw new NotFoundError("Vehicle not found");

  if (actor.role === UserRole.DRIVER && vehicle.assignedDriverId !== actor.id) {
    throw new ForbiddenError("You can only access your assigned vehicle");
  }

  return vehicle;
}

export async function getMyVehicle(actor: AuthenticatedUser) {
  const vehicle = await prisma.vehicle.findFirst({
    where: { assignedDriverId: actor.id, organizationId: actor.organizationId, deletedAt: null },
  });
  if (!vehicle) throw new NotFoundError("No vehicle is currently assigned to you");
  return vehicle;
}

export async function createVehicle(actor: AuthenticatedUser, input: CreateVehicleInput) {
  // Only Super Admin can register vehicles by default.
  // Fleet Manager needs explicit VEHICLE_MANAGEMENT permission granted by Super Admin.
  if (actor.role !== UserRole.SUPER_ADMIN) {
    if (actor.role === UserRole.FLEET_MANAGER) {
      const permitted = await hasPermission(actor.id, PermissionType.VEHICLE_MANAGEMENT);
      if (!permitted) {
        throw new ForbiddenError(
          "Vehicle registration requires Super Admin permission. Contact your Super Admin to grant VEHICLE_MANAGEMENT access."
        );
      }
    } else {
      throw new ForbiddenError("Only Super Admin can register vehicles");
    }
  }

  const existing = await prisma.vehicle.findUnique({ where: { plateNumber: input.plateNumber } });
  if (existing) throw new ConflictError("A vehicle with this plate number already exists");

  return prisma.vehicle.create({
    data: {
      organizationId: actor.organizationId,
      plateNumber: input.plateNumber,
      make: input.make,
      model: input.model,
      year: input.year,
      vehicleType: input.vehicleType,
      fuelType: input.fuelType,
      tankCapacityL: input.tankCapacityL,
      currentFuelL: input.currentFuelL,
      odometerKm: input.odometerKm,
      fuelEfficiencyKmpl: input.fuelEfficiencyKmpl,
      color: input.color,
      notes: input.notes,
    },
  });
}

export async function updateVehicle(actor: AuthenticatedUser, id: string, input: UpdateVehicleInput) {
  const vehicle = await loadVehicle(actor, id);

  if (input.plateNumber && input.plateNumber !== vehicle.plateNumber) {
    const existing = await prisma.vehicle.findUnique({ where: { plateNumber: input.plateNumber } });
    if (existing) throw new ConflictError("A vehicle with this plate number already exists");
  }

  const affectsAllocation =
    (input.fuelEfficiencyKmpl !== undefined && input.fuelEfficiencyKmpl !== vehicle.fuelEfficiencyKmpl.toNumber()) ||
    (input.fuelType !== undefined && input.fuelType !== vehicle.fuelType);

  const updated = await prisma.vehicle.update({
    where: { id: vehicle.id },
    data: {
      plateNumber: input.plateNumber,
      make: input.make,
      model: input.model,
      year: input.year,
      vehicleType: input.vehicleType,
      fuelType: input.fuelType,
      tankCapacityL: input.tankCapacityL,
      currentFuelL: input.currentFuelL,
      odometerKm: input.odometerKm,
      fuelEfficiencyKmpl: input.fuelEfficiencyKmpl,
      status: input.status,
      color: input.color,
      notes: input.notes,
    },
  });

  if (affectsAllocation && updated.assignedDriverId) {
    await recomputeAllocationForDriver(updated.assignedDriverId, "vehicle_updated", actor.id);
  }

  return updated;
}

export async function assignDriver(actor: AuthenticatedUser, id: string, input: AssignDriverInput) {
  const vehicle = await loadVehicle(actor, id);
  const previousDriverId = vehicle.assignedDriverId;
  const newDriverId = input.driverId;

  if (newDriverId === previousDriverId) {
    return vehicle;
  }

  if (newDriverId) {
    const driver = await prisma.user.findFirst({
      where: { id: newDriverId, organizationId: actor.organizationId, deletedAt: null, role: UserRole.DRIVER },
    });
    if (!driver) throw new NotFoundError("Driver not found");

    // A driver can only have one assigned vehicle - clear any existing assignment first.
    await prisma.vehicle.updateMany({
      where: { assignedDriverId: newDriverId, deletedAt: null },
      data: { assignedDriverId: null, status: VehicleStatus.UNASSIGNED },
    });
  }

  const updated = await prisma.vehicle.update({
    where: { id: vehicle.id },
    data: {
      assignedDriverId: newDriverId,
      status: newDriverId ? VehicleStatus.ACTIVE : VehicleStatus.UNASSIGNED,
    },
  });

  if (previousDriverId) {
    await recomputeAllocationForDriver(previousDriverId, "vehicle_unassigned", actor.id);
  }

  if (newDriverId) {
    await emit("vehicle_assignment_changed", [newDriverId], { plateNumber: updated.plateNumber });
    await recomputeAllocationForDriver(newDriverId, "vehicle_assigned", actor.id);
  }

  return updated;
}

export async function deleteVehicle(actor: AuthenticatedUser, id: string): Promise<void> {
  // Only Super Admin can delete vehicles by default.
  // Fleet Manager needs explicit VEHICLE_MANAGEMENT permission granted by Super Admin.
  if (actor.role !== UserRole.SUPER_ADMIN) {
    if (actor.role === UserRole.FLEET_MANAGER) {
      const permitted = await hasPermission(actor.id, PermissionType.VEHICLE_MANAGEMENT);
      if (!permitted) {
        throw new ForbiddenError(
          "Vehicle deletion requires Super Admin permission. Contact your Super Admin to grant VEHICLE_MANAGEMENT access."
        );
      }
    } else {
      throw new ForbiddenError("Only Super Admin can delete vehicles");
    }
  }

  const vehicle = await loadVehicle(actor, id);

  await prisma.vehicle.update({
    where: { id: vehicle.id },
    data: { deletedAt: new Date(), assignedDriverId: null, status: VehicleStatus.RETIRED },
  });

  if (vehicle.assignedDriverId) {
    await recomputeAllocationForDriver(vehicle.assignedDriverId, "vehicle_unassigned", actor.id);
  }
}

async function loadVehicle(actor: AuthenticatedUser, id: string) {
  const vehicle = await prisma.vehicle.findFirst({ where: { id, organizationId: actor.organizationId, deletedAt: null } });
  if (!vehicle) throw new NotFoundError("Vehicle not found");
  return vehicle;
}

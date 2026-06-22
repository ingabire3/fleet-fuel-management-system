import { Prisma, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { polylineLengthKm, computeRouteDeviation } from "../../lib/geo/routeDeviation";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { CreateApprovedRouteInput, ListApprovedRoutesQuery, UpdateApprovedRouteInput } from "./approved-routes.validators";

const ROUTE_INCLUDE = {
  waypoints: { orderBy: { sequenceNo: "asc" } },
  driver: { select: { id: true, fullName: true } },
  vehicle: { select: { id: true, plateNumber: true } },
} satisfies Prisma.ApprovedRouteInclude;

export async function listApprovedRoutes(actor: AuthenticatedUser, query: ListApprovedRoutesQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.ApprovedRouteWhereInput = {
    driver: { organizationId: actor.organizationId },
    deletedAt: null,
  };

  if (actor.role === UserRole.DRIVER) {
    where.driverId = actor.id;
  } else if (query.driverId) {
    where.driverId = query.driverId;
  }

  const [data, total] = await Promise.all([
    prisma.approvedRoute.findMany({
      where,
      include: ROUTE_INCLUDE,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.approvedRoute.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getApprovedRouteById(actor: AuthenticatedUser, id: string) {
  return loadRoute(actor, id);
}

/** Returns the driver's currently active approved route (with ordered waypoints), or `null`. */
export async function getActiveRouteForDriver(driverId: string) {
  return prisma.approvedRoute.findFirst({
    where: { driverId, isActive: true, deletedAt: null },
    include: ROUTE_INCLUDE,
  });
}

export async function createApprovedRoute(actor: AuthenticatedUser, input: CreateApprovedRouteInput) {
  const driver = await prisma.user.findFirst({
    where: { id: input.driverId, organizationId: actor.organizationId, role: UserRole.DRIVER, deletedAt: null },
    include: { assignedVehicle: true },
  });
  if (!driver) throw new NotFoundError("Driver not found");
  if (!driver.assignedVehicle) throw new ForbiddenError("Driver has no assigned vehicle");

  const totalDistanceKm = polylineLengthKm(input.waypoints.map((wp) => ({ lat: wp.latitude, lng: wp.longitude })));

  const route = await prisma.$transaction(async (tx) => {
    await tx.approvedRoute.updateMany({
      where: { driverId: driver.id, isActive: true, deletedAt: null },
      data: { isActive: false },
    });

    return tx.approvedRoute.create({
      data: {
        driverId: driver.id,
        vehicleId: driver.assignedVehicle!.id,
        name: input.name ?? "Home-Work Commute",
        totalDistanceKm,
        toleranceKm: input.toleranceKm,
        createdById: actor.id,
        waypoints: {
          create: input.waypoints.map((wp, index) => ({
            sequenceNo: index + 1,
            latitude: wp.latitude,
            longitude: wp.longitude,
            label: wp.label,
          })),
        },
      },
      include: ROUTE_INCLUDE,
    });
  });

  return route;
}

export async function updateApprovedRoute(actor: AuthenticatedUser, id: string, input: UpdateApprovedRouteInput) {
  const route = await loadRoute(actor, id);

  const totalDistanceKm = input.waypoints
    ? polylineLengthKm(input.waypoints.map((wp) => ({ lat: wp.latitude, lng: wp.longitude })))
    : undefined;

  return prisma.$transaction(async (tx) => {
    if (input.waypoints) {
      await tx.approvedRouteWaypoint.deleteMany({ where: { approvedRouteId: route.id } });
    }

    return tx.approvedRoute.update({
      where: { id: route.id },
      data: {
        name: input.name,
        toleranceKm: input.toleranceKm,
        isActive: input.isActive,
        totalDistanceKm,
        waypoints: input.waypoints
          ? {
              create: input.waypoints.map((wp, index) => ({
                sequenceNo: index + 1,
                latitude: wp.latitude,
                longitude: wp.longitude,
                label: wp.label,
              })),
            }
          : undefined,
      },
      include: ROUTE_INCLUDE,
    });
  });
}

export async function deleteApprovedRoute(actor: AuthenticatedUser, id: string): Promise<void> {
  const route = await loadRoute(actor, id);

  await prisma.approvedRoute.update({
    where: { id: route.id },
    data: { isActive: false, deletedAt: new Date() },
  });
}

export async function getRouteTripComparison(actor: AuthenticatedUser, routeId: string, tripId: string) {
  const route = await loadRoute(actor, routeId);

  const trip = await prisma.gpsTrip.findFirst({
    where: { id: tripId, driverId: route.driverId },
    include: { waypoints: { orderBy: { sequenceNo: "asc" } } },
  });
  if (!trip) throw new NotFoundError("Trip not found for this route");

  const routePoints = route.waypoints.map((wp) => ({ lat: wp.latitude.toNumber(), lng: wp.longitude.toNumber() }));
  const tripPoints = trip.waypoints.map((wp) => ({ lat: wp.latitude.toNumber(), lng: wp.longitude.toNumber() }));

  const deviation = computeRouteDeviation(tripPoints, routePoints, route.toleranceKm.toNumber());

  return {
    route: { id: route.id, name: route.name, totalDistanceKm: route.totalDistanceKm.toNumber(), toleranceKm: route.toleranceKm.toNumber(), points: routePoints },
    trip: { id: trip.id, distanceKm: trip.distanceKm?.toNumber() ?? null, points: tripPoints },
    deviation,
  };
}

async function loadRoute(actor: AuthenticatedUser, id: string): Promise<Prisma.ApprovedRouteGetPayload<{ include: typeof ROUTE_INCLUDE }>> {
  const route = await prisma.approvedRoute.findFirst({
    where: { id, driver: { organizationId: actor.organizationId }, deletedAt: null },
    include: ROUTE_INCLUDE,
  });
  if (!route) throw new NotFoundError("Approved route not found");

  if (actor.role === UserRole.DRIVER && route.driverId !== actor.id) {
    throw new ForbiddenError("You can only access your own approved route");
  }

  return route;
}

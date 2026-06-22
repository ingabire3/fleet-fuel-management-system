import { AlertSeverity, AlertType, Prisma, TripStatus, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError, ConflictError } from "../../lib/errors";
import { computeDetourDistanceKm, computeRouteDeviation, polylineLengthKm } from "../../lib/geo/routeDeviation";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { emit } from "../notifications/notification-dispatcher";
import { getActiveRouteForDriver } from "../routes-approved/approved-routes.service";
import { AddWaypointInput, EndTripInput, ListTripsQuery, StartTripInput } from "./gps-tracking.validators";

const TRIP_INCLUDE = {
  waypoints: { orderBy: { sequenceNo: "asc" } },
  driver: { select: { id: true, fullName: true } },
  vehicle: { select: { id: true, plateNumber: true } },
} satisfies Prisma.GpsTripInclude;

export async function listTrips(actor: AuthenticatedUser, query: ListTripsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.GpsTripWhereInput = {
    driver: { organizationId: actor.organizationId },
  };

  if (actor.role === UserRole.DRIVER) {
    where.driverId = actor.id;
  } else if (query.driverId) {
    where.driverId = query.driverId;
  }

  if (query.vehicleId) where.vehicleId = query.vehicleId;
  if (query.status) where.status = query.status;

  const [data, total] = await Promise.all([
    prisma.gpsTrip.findMany({
      where,
      include: TRIP_INCLUDE,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.gpsTrip.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getTripById(actor: AuthenticatedUser, id: string) {
  return loadTrip(actor, id);
}

export async function startTrip(actor: AuthenticatedUser, input: StartTripInput) {
  if (actor.role !== UserRole.DRIVER) {
    throw new ForbiddenError("Only drivers can start trips");
  }

  const vehicle = await prisma.vehicle.findFirst({
    where: { assignedDriverId: actor.id, organizationId: actor.organizationId, deletedAt: null },
  });
  if (!vehicle) throw new ForbiddenError("You do not have a vehicle assigned");

  const existing = await prisma.gpsTrip.findFirst({
    where: { driverId: actor.id, status: TripStatus.IN_PROGRESS },
  });
  if (existing) throw new ConflictError("You already have a trip in progress");

  const activeRoute = await getActiveRouteForDriver(actor.id);

  return prisma.gpsTrip.create({
    data: {
      vehicleId: vehicle.id,
      driverId: actor.id,
      status: TripStatus.IN_PROGRESS,
      startedAt: new Date(),
      originName: input.originName,
      originLat: input.originLat,
      originLng: input.originLng,
      destinationName: input.destinationName,
      destinationLat: input.destinationLat,
      destinationLng: input.destinationLng,
      approvedRouteId: activeRoute?.id,
    },
    include: TRIP_INCLUDE,
  });
}

export async function addWaypoint(actor: AuthenticatedUser, tripId: string, input: AddWaypointInput) {
  const trip = await loadTrip(actor, tripId);

  if (actor.role !== UserRole.DRIVER || trip.driverId !== actor.id) {
    throw new ForbiddenError("You can only record waypoints for your own trip");
  }
  if (trip.status !== TripStatus.IN_PROGRESS) {
    throw new ConflictError("Trip is not in progress");
  }

  const lastWaypoint = trip.waypoints[trip.waypoints.length - 1];
  const sequenceNo = (lastWaypoint?.sequenceNo ?? 0) + 1;

  const waypoint = await prisma.tripWaypoint.create({
    data: {
      tripId: trip.id,
      sequenceNo,
      latitude: input.latitude,
      longitude: input.longitude,
      speedKmh: input.speedKmh,
      fuelLevelL: input.fuelLevelL,
      recordedAt: input.recordedAt,
    },
  });

  if (trip.approvedRouteId && !trip.isDetourFlagged) {
    const route = await prisma.approvedRoute.findUnique({
      where: { id: trip.approvedRouteId },
      include: { waypoints: { orderBy: { sequenceNo: "asc" } } },
    });

    if (route) {
      const routePoints = route.waypoints.map((wp) => ({ lat: wp.latitude.toNumber(), lng: wp.longitude.toNumber() }));
      const tripPoints = [...trip.waypoints, waypoint].map((wp) => ({ lat: wp.latitude.toNumber(), lng: wp.longitude.toNumber() }));

      const deviation = computeRouteDeviation(tripPoints, routePoints, route.toleranceKm.toNumber());

      await prisma.gpsTrip.update({
        where: { id: trip.id },
        data: { maxDeviationKm: deviation.maxDeviationKm, isDetourFlagged: deviation.isDetourFlagged },
      });

      if (deviation.isDetourFlagged) {
        await prisma.alert.create({
          data: {
            driverId: trip.driverId,
            vehicleId: trip.vehicleId,
            tripId: trip.id,
            alertType: AlertType.ROUTE_DETOUR,
            severity: AlertSeverity.MEDIUM,
            title: "Route detour detected",
            description: `Driver deviated ${deviation.maxDeviationKm.toFixed(2)}km from the approved route (tolerance ${route.toleranceKm.toFixed(2)}km).`,
          },
        });

        const recipients = await getStaffIds(actor.organizationId, [UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER]);
        await emit("route_detour", recipients, { driverName: trip.driver.fullName, deviationKm: deviation.maxDeviationKm });
      }
    }
  }

  return waypoint;
}

export async function endTrip(actor: AuthenticatedUser, tripId: string, input: EndTripInput) {
  const trip = await loadTrip(actor, tripId);

  if (actor.role !== UserRole.DRIVER || trip.driverId !== actor.id) {
    throw new ForbiddenError("You can only end your own trip");
  }
  if (trip.status !== TripStatus.IN_PROGRESS) {
    throw new ConflictError("Trip is not in progress");
  }

  const endedAt = new Date();
  const startedAt = trip.startedAt ?? endedAt;
  const durationMinutes = Math.max(0, Math.round((endedAt.getTime() - startedAt.getTime()) / 60000));

  const distanceKm = input.distanceKm ?? polylineLengthKm(trip.waypoints.map((wp) => ({ lat: wp.latitude.toNumber(), lng: wp.longitude.toNumber() })));

  let detourDistanceKm: number | undefined;
  if (trip.approvedRouteId) {
    const route = await prisma.approvedRoute.findUnique({ where: { id: trip.approvedRouteId } });
    if (route) {
      detourDistanceKm = computeDetourDistanceKm(distanceKm, route.totalDistanceKm.toNumber());
    }
  }

  return prisma.gpsTrip.update({
    where: { id: trip.id },
    data: {
      status: TripStatus.COMPLETED,
      endedAt,
      durationMinutes,
      distanceKm,
      fuelConsumedL: input.fuelConsumedL,
      detourDistanceKm,
    },
    include: TRIP_INCLUDE,
  });
}

export async function cancelTrip(actor: AuthenticatedUser, tripId: string) {
  const trip = await loadTrip(actor, tripId);

  if (actor.role !== UserRole.DRIVER || trip.driverId !== actor.id) {
    throw new ForbiddenError("You can only cancel your own trip");
  }
  if (trip.status !== TripStatus.PLANNED && trip.status !== TripStatus.IN_PROGRESS) {
    throw new ConflictError("Trip cannot be cancelled in its current state");
  }

  return prisma.gpsTrip.update({
    where: { id: trip.id },
    data: { status: TripStatus.CANCELLED, endedAt: new Date() },
    include: TRIP_INCLUDE,
  });
}

/** Returns the most recent waypoint for every trip currently in progress (for a live fleet map). */
export async function getLivePositions(actor: AuthenticatedUser) {
  const trips = await prisma.gpsTrip.findMany({
    where: { driver: { organizationId: actor.organizationId }, status: TripStatus.IN_PROGRESS },
    include: {
      driver: { select: { id: true, fullName: true } },
      vehicle: { select: { id: true, plateNumber: true } },
      waypoints: { orderBy: { sequenceNo: "desc" }, take: 1 },
    },
  });

  return trips.map((trip) => {
    const latest = trip.waypoints[0];
    return {
      tripId: trip.id,
      driver: trip.driver,
      vehicle: trip.vehicle,
      position: latest
        ? { latitude: latest.latitude.toNumber(), longitude: latest.longitude.toNumber(), recordedAt: latest.recordedAt }
        : null,
    };
  });
}

async function loadTrip(actor: AuthenticatedUser, id: string) {
  const trip = await prisma.gpsTrip.findFirst({
    where: { id, driver: { organizationId: actor.organizationId } },
    include: TRIP_INCLUDE,
  });
  if (!trip) throw new NotFoundError("Trip not found");

  if (actor.role === UserRole.DRIVER && trip.driverId !== actor.id) {
    throw new ForbiddenError("You can only access your own trips");
  }

  return trip;
}

async function getStaffIds(organizationId: string, roles: UserRole[]): Promise<string[]> {
  const staff = await prisma.user.findMany({
    where: { organizationId, role: { in: roles }, deletedAt: null, isActive: true },
    select: { id: true },
  });
  return staff.map((u) => u.id);
}

import { z } from "zod";

const statusEnum = z.enum(["PLANNED", "IN_PROGRESS", "COMPLETED", "CANCELLED"]);

export const tripIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const listTripsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  driverId: z.string().uuid().optional(),
  vehicleId: z.string().uuid().optional(),
  status: statusEnum.optional(),
});

export const startTripSchema = z.object({
  originName: z.string().max(255).optional(),
  originLat: z.number().min(-90).max(90).optional(),
  originLng: z.number().min(-180).max(180).optional(),
  destinationName: z.string().max(255).optional(),
  destinationLat: z.number().min(-90).max(90).optional(),
  destinationLng: z.number().min(-180).max(180).optional(),
});

export const addWaypointSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  speedKmh: z.number().nonnegative().optional(),
  fuelLevelL: z.number().nonnegative().optional(),
  recordedAt: z.coerce.date().optional(),
});

export const endTripSchema = z.object({
  distanceKm: z.number().nonnegative().optional(),
  fuelConsumedL: z.number().nonnegative().optional(),
});

export type StartTripInput = z.infer<typeof startTripSchema>;
export type AddWaypointInput = z.infer<typeof addWaypointSchema>;
export type EndTripInput = z.infer<typeof endTripSchema>;
export type ListTripsQuery = z.infer<typeof listTripsQuerySchema>;

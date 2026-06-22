import { z } from "zod";

export const routeIdParamsSchema = z.object({
  id: z.string().uuid(),
});

export const routeTripParamsSchema = z.object({
  id: z.string().uuid(),
  tripId: z.string().uuid(),
});

export const listApprovedRoutesQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  driverId: z.string().uuid().optional(),
});

const waypointSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  label: z.string().max(120).optional(),
});

export const createApprovedRouteSchema = z.object({
  driverId: z.string().uuid(),
  name: z.string().max(120).optional(),
  toleranceKm: z.number().positive().optional(),
  waypoints: z.array(waypointSchema).min(2),
});

export const updateApprovedRouteSchema = z.object({
  name: z.string().max(120).optional(),
  toleranceKm: z.number().positive().optional(),
  isActive: z.boolean().optional(),
  waypoints: z.array(waypointSchema).min(2).optional(),
});

export type CreateApprovedRouteInput = z.infer<typeof createApprovedRouteSchema>;
export type UpdateApprovedRouteInput = z.infer<typeof updateApprovedRouteSchema>;
export type ListApprovedRoutesQuery = z.infer<typeof listApprovedRoutesQuerySchema>;

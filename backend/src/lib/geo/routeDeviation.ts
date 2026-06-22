import { LatLng, haversineKm } from "./haversine";

/** Projects lat/lng to a local flat-earth x/y plane (km) centered on `origin`.
 *  Sufficiently accurate for short commute-distance deviation checks. */
function toLocalXY(point: LatLng, origin: LatLng): { x: number; y: number } {
  const kmPerDegLat = 110.574;
  const kmPerDegLng = 111.32 * Math.cos((origin.lat * Math.PI) / 180);

  return {
    x: (point.lng - origin.lng) * kmPerDegLng,
    y: (point.lat - origin.lat) * kmPerDegLat,
  };
}

/** Shortest distance (km) from `point` to the segment `segA`-`segB`. */
export function pointToSegmentDistanceKm(point: LatLng, segA: LatLng, segB: LatLng): number {
  const p = toLocalXY(point, segA);
  const a = { x: 0, y: 0 };
  const b = toLocalXY(segB, segA);

  const abx = b.x - a.x;
  const aby = b.y - a.y;
  const lengthSq = abx * abx + aby * aby;

  let t = lengthSq === 0 ? 0 : ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq;
  t = Math.max(0, Math.min(1, t));

  const closest = { x: a.x + t * abx, y: a.y + t * aby };
  const dx = p.x - closest.x;
  const dy = p.y - closest.y;

  return Math.sqrt(dx * dx + dy * dy);
}

/** Shortest distance (km) from `point` to a polyline defined by `routePoints` (in order). */
export function pointToPolylineDistanceKm(point: LatLng, routePoints: LatLng[]): number {
  if (routePoints.length === 0) return Infinity;
  if (routePoints.length === 1) return haversineKm(point, routePoints[0]);

  let min = Infinity;
  for (let i = 0; i < routePoints.length - 1; i++) {
    const d = pointToSegmentDistanceKm(point, routePoints[i], routePoints[i + 1]);
    if (d < min) min = d;
  }
  return min;
}

export interface RouteDeviationResult {
  maxDeviationKm: number;
  isDetourFlagged: boolean;
}

/** Compares actual trip waypoints against an approved route polyline.
 *  Flags a detour if any waypoint strays further than `toleranceKm` from the route. */
export function computeRouteDeviation(
  tripWaypoints: LatLng[],
  approvedRoutePoints: LatLng[],
  toleranceKm: number
): RouteDeviationResult {
  if (tripWaypoints.length === 0 || approvedRoutePoints.length === 0) {
    return { maxDeviationKm: 0, isDetourFlagged: false };
  }

  let maxDeviationKm = 0;
  for (const wp of tripWaypoints) {
    const d = pointToPolylineDistanceKm(wp, approvedRoutePoints);
    if (d > maxDeviationKm) maxDeviationKm = d;
  }

  return {
    maxDeviationKm,
    isDetourFlagged: maxDeviationKm > toleranceKm,
  };
}

/** Extra distance travelled vs the approved route's total distance (never negative). */
export function computeDetourDistanceKm(actualDistanceKm: number, approvedDistanceKm: number): number {
  return Math.max(0, actualDistanceKm - approvedDistanceKm);
}

/** Total length (km) of a polyline, summing haversine distance between consecutive points. */
export function polylineLengthKm(points: LatLng[]): number {
  let total = 0;
  for (let i = 0; i < points.length - 1; i++) {
    total += haversineKm(points[i], points[i + 1]);
  }
  return total;
}

import { haversineKm, LatLng } from "../../lib/geo/haversine";

export interface AllocationInputs {
  home: LatLng;
  work: LatLng;
  workingDays: number;
  vehicleEfficiencyKmpl: number;
  roadDistanceFactor: number;
  bufferPercent: number;
  fuelPriceRwf: number;
  extraFuelGrantedL: number;
}

export interface AllocationResult {
  /** One-way straight-line (haversine) distance between home and work, in km. */
  oneWayKm: number;
  /** Round-trip road distance per working day (one-way road distance * roadDistanceFactor * 2), in km. */
  distanceKm: number;
  baseRequirementL: number;
  bufferL: number;
  finalAllocationL: number;
  totalAvailableL: number;
  projectedCostRwf: number;
}

/**
 * Computes a driver's monthly fuel allocation.
 *
 * Base = oneWayKm * roadDistanceFactor * 2 (round trip) * workingDays / vehicleEfficiencyKmpl
 * Buffer = Base * bufferPercent / 100
 * Final = Base + Buffer
 * Total available = Final + extraFuelGrantedL (finance-approved extra fuel this period)
 */
export function computeAllocation(inputs: AllocationInputs): AllocationResult {
  const oneWayKm = haversineKm(inputs.home, inputs.work);
  const distanceKm = oneWayKm * inputs.roadDistanceFactor * 2;

  const baseRequirementL = (distanceKm * inputs.workingDays) / inputs.vehicleEfficiencyKmpl;
  const bufferL = baseRequirementL * (inputs.bufferPercent / 100);
  const finalAllocationL = baseRequirementL + bufferL;
  const totalAvailableL = finalAllocationL + inputs.extraFuelGrantedL;
  const projectedCostRwf = totalAvailableL * inputs.fuelPriceRwf;

  return { oneWayKm, distanceKm, baseRequirementL, bufferL, finalAllocationL, totalAvailableL, projectedCostRwf };
}

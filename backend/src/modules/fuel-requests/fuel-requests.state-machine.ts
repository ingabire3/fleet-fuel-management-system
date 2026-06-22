import { FuelRequestStatus } from "@prisma/client";
import { InvalidTransitionError } from "../../lib/errors";

const TRANSITIONS: Record<FuelRequestStatus, FuelRequestStatus[]> = {
  PENDING: [
    FuelRequestStatus.FLEET_MANAGER_APPROVED,
    FuelRequestStatus.FLEET_MANAGER_REJECTED,
    FuelRequestStatus.CANCELLED,
  ],
  FLEET_MANAGER_APPROVED: [FuelRequestStatus.FINANCE_APPROVED, FuelRequestStatus.FINANCE_REJECTED, FuelRequestStatus.CANCELLED],
  FLEET_MANAGER_REJECTED: [],
  FINANCE_APPROVED: [],
  FINANCE_REJECTED: [],
  CANCELLED: [],
};

export function assertTransition(from: FuelRequestStatus, to: FuelRequestStatus): void {
  if (!TRANSITIONS[from].includes(to)) {
    throw new InvalidTransitionError(`Cannot transition fuel request from ${from} to ${to}`);
  }
}

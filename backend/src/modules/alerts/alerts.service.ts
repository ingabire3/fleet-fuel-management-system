import { AlertStatus, AlertType, Prisma, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { ListAlertsQuery, UpdateAlertStatusInput } from "./alerts.validators";

const ALERT_INCLUDE = {
  driver: { select: { id: true, fullName: true } },
  vehicle: { select: { id: true, plateNumber: true } },
} satisfies Prisma.AlertInclude;

export async function listAlerts(actor: AuthenticatedUser, query: ListAlertsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.AlertWhereInput = {};

  if (actor.role === UserRole.DRIVER) {
    where.driverId = actor.id;
  } else {
    where.OR = [{ driver: { organizationId: actor.organizationId } }, { vehicle: { organizationId: actor.organizationId } }];
    if (query.driverId) where.driverId = query.driverId;
    if (query.vehicleId) where.vehicleId = query.vehicleId;
  }

  if (query.status) where.status = query.status;
  if (query.alertType) where.alertType = query.alertType;
  if (query.severity) where.severity = query.severity;

  const [data, total] = await Promise.all([
    prisma.alert.findMany({
      where,
      include: ALERT_INCLUDE,
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.alert.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

export async function getAlertById(actor: AuthenticatedUser, id: string) {
  return loadAlert(actor, id);
}

export async function updateAlertStatus(actor: AuthenticatedUser, id: string, input: UpdateAlertStatusInput) {
  const alert = await loadAlert(actor, id);

  if (actor.role === UserRole.DRIVER) {
    throw new ForbiddenError("Drivers cannot update alert status");
  }
  if (actor.role === UserRole.FINANCE_OFFICER && alert.alertType !== AlertType.BUDGET_EXCEEDED) {
    throw new ForbiddenError("Finance officers can only manage budget alerts");
  }

  return prisma.alert.update({
    where: { id: alert.id },
    data: {
      status: input.status,
      resolvedById: input.status === AlertStatus.RESOLVED ? actor.id : alert.resolvedById,
      resolvedAt: input.status === AlertStatus.RESOLVED ? new Date() : alert.resolvedAt,
    },
    include: ALERT_INCLUDE,
  });
}

async function loadAlert(actor: AuthenticatedUser, id: string) {
  const alert = await prisma.alert.findFirst({
    where: {
      id,
      OR: [{ driver: { organizationId: actor.organizationId } }, { vehicle: { organizationId: actor.organizationId } }],
    },
    include: ALERT_INCLUDE,
  });
  if (!alert) throw new NotFoundError("Alert not found");

  if (actor.role === UserRole.DRIVER && alert.driverId !== actor.id) {
    throw new ForbiddenError("You can only access your own alerts");
  }

  return alert;
}

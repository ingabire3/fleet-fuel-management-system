import { Prisma } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { buildPaginatedResult, parsePagination } from "../../lib/pagination";
import { AuthenticatedUser } from "../../types/auth";
import { ListAuditLogsQuery } from "./audit.validators";

export async function listAuditLogs(actor: AuthenticatedUser, query: ListAuditLogsQuery) {
  const pagination = parsePagination(query);

  const where: Prisma.AuditLogWhereInput = {
    actor: { organizationId: actor.organizationId },
  };

  if (query.actorId) where.actorId = query.actorId;
  if (query.entityType) where.entityType = query.entityType;
  if (query.action) where.action = query.action;
  if (query.from || query.to) {
    where.createdAt = {
      ...(query.from ? { gte: query.from } : {}),
      ...(query.to ? { lte: query.to } : {}),
    };
  }

  const [data, total] = await Promise.all([
    prisma.auditLog.findMany({
      where,
      include: { actor: { select: { id: true, fullName: true, email: true, role: true } } },
      orderBy: { createdAt: "desc" },
      skip: pagination.skip,
      take: pagination.take,
    }),
    prisma.auditLog.count({ where }),
  ]);

  return buildPaginatedResult(data, total, pagination);
}

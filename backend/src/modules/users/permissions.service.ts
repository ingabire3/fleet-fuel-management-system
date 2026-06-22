import { AuditAction, PermissionType, UserRole } from "@prisma/client";
import { prisma } from "../../config/prisma";
import { ForbiddenError, NotFoundError } from "../../lib/errors";
import { AuthenticatedUser } from "../../types/auth";
import { GrantPermissionInput } from "./permissions.validators";

export async function listPermissions(actor: AuthenticatedUser, userId: string) {
  const target = await prisma.user.findFirst({
    where: { id: userId, organizationId: actor.organizationId, deletedAt: null },
    select: { id: true, fullName: true, role: true },
  });
  if (!target) throw new NotFoundError("User not found");

  if (actor.role !== UserRole.SUPER_ADMIN && actor.id !== userId) {
    throw new ForbiddenError("Only Super Admin can view other users' permissions");
  }

  return prisma.userPermission.findMany({
    where: { userId, revokedAt: null },
    include: {
      grantedBy: { select: { id: true, fullName: true } },
    },
    orderBy: { grantedAt: "desc" },
  });
}

export async function grantPermission(actor: AuthenticatedUser, userId: string, input: GrantPermissionInput) {
  if (actor.role !== UserRole.SUPER_ADMIN) {
    throw new ForbiddenError("Only Super Admin can grant permissions");
  }

  const target = await prisma.user.findFirst({
    where: { id: userId, organizationId: actor.organizationId, deletedAt: null },
    select: { id: true, fullName: true, role: true },
  });
  if (!target) throw new NotFoundError("User not found");

  if (target.role === UserRole.SUPER_ADMIN) {
    throw new ForbiddenError("Cannot grant additional permissions to Super Admin — they already have full access");
  }

  const permission = await prisma.userPermission.upsert({
    where: { userId_permission: { userId, permission: input.permission as PermissionType } },
    update: { grantedById: actor.id, grantedAt: new Date(), revokedAt: null, revokedById: null },
    create: { userId, permission: input.permission as PermissionType, grantedById: actor.id },
    include: { grantedBy: { select: { id: true, fullName: true } } },
  });

  await prisma.auditLog.create({
    data: {
      actorId: actor.id,
      action: AuditAction.PERMISSION_CHANGE,
      entityType: "UserPermission",
      entityId: userId,
      metadata: {
        userId,
        userFullName: target.fullName,
        userRole: target.role,
        permission: input.permission,
        action: "GRANTED",
        reason: input.reason ?? null,
        grantedById: actor.id,
      },
    },
  });

  return permission;
}

export async function revokePermission(actor: AuthenticatedUser, userId: string, permission: PermissionType) {
  if (actor.role !== UserRole.SUPER_ADMIN) {
    throw new ForbiddenError("Only Super Admin can revoke permissions");
  }

  const target = await prisma.user.findFirst({
    where: { id: userId, organizationId: actor.organizationId, deletedAt: null },
    select: { id: true, fullName: true, role: true },
  });
  if (!target) throw new NotFoundError("User not found");

  const existing = await prisma.userPermission.findUnique({
    where: { userId_permission: { userId, permission } },
  });
  if (!existing || existing.revokedAt !== null) {
    throw new NotFoundError("Permission not found or already revoked");
  }

  await prisma.userPermission.update({
    where: { userId_permission: { userId, permission } },
    data: { revokedAt: new Date(), revokedById: actor.id },
  });

  await prisma.auditLog.create({
    data: {
      actorId: actor.id,
      action: AuditAction.PERMISSION_CHANGE,
      entityType: "UserPermission",
      entityId: userId,
      metadata: {
        userId,
        userFullName: target.fullName,
        userRole: target.role,
        permission,
        action: "REVOKED",
        revokedById: actor.id,
      },
    },
  });
}

/** Service-layer helper — checks if a user has an active (non-revoked) permission. */
export async function hasPermission(userId: string, permission: PermissionType): Promise<boolean> {
  const perm = await prisma.userPermission.findUnique({
    where: { userId_permission: { userId, permission } },
    select: { revokedAt: true },
  });
  return perm !== null && perm.revokedAt === null;
}

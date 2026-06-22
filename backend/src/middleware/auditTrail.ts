import { NextFunction, Request, Response } from "express";
import { AuditAction } from "@prisma/client";
import { prisma } from "../config/prisma";
import { logger } from "../config/logger";

const METHOD_ACTION: Record<string, AuditAction> = {
  POST: AuditAction.CREATE,
  PUT: AuditAction.UPDATE,
  PATCH: AuditAction.UPDATE,
  DELETE: AuditAction.DELETE,
};

/** Writes an AuditLog row for mutating requests (POST/PUT/PATCH/DELETE) on successful responses.
 *  Attach per-router with the entity type it manages, e.g. `auditTrail("Vehicle")`. */
export function auditTrail(entityType: string) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const action = METHOD_ACTION[req.method];
    if (!action) {
      next();
      return;
    }

    res.on("finish", () => {
      if (res.statusCode >= 400) return;

      const entityId = req.params.id ?? (res.locals.auditEntityId as string | undefined);

      prisma.auditLog
        .create({
          data: {
            actorId: req.user?.id,
            action,
            entityType,
            entityId,
            ipAddress: req.ip,
            userAgent: req.headers["user-agent"],
          },
        })
        .catch((err) => logger.error({ err }, "Failed to write audit log"));
    });

    next();
  };
}

import { z } from "zod";
import { AuditAction } from "@prisma/client";

export const listAuditLogsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().optional(),
  actorId: z.string().uuid().optional(),
  entityType: z.string().optional(),
  action: z.nativeEnum(AuditAction).optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
});

export type ListAuditLogsQuery = z.infer<typeof listAuditLogsQuerySchema>;

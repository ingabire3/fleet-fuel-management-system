import { asyncHandler } from "../../lib/asyncHandler";
import { UnauthorizedError } from "../../lib/errors";
import * as auditService from "./audit.service";
import { ListAuditLogsQuery } from "./audit.validators";

export const list = asyncHandler(async (req, res) => {
  if (!req.user) throw new UnauthorizedError();
  const result = await auditService.listAuditLogs(req.user, req.query as unknown as ListAuditLogsQuery);
  res.status(200).json(result);
});

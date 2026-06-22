import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { validate } from "../../middleware/validate";
import * as controller from "./audit.controller";
import { listAuditLogsQuerySchema } from "./audit.validators";

const router = Router();

router.use(authenticate);

router.get(
  "/",
  authorize(UserRole.SUPER_ADMIN),
  validate({ query: listAuditLogsQuerySchema }),
  controller.list
);

export default router;

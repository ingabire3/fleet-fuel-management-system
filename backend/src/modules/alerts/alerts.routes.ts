import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./alerts.controller";
import { alertIdParamsSchema, listAlertsQuerySchema, updateAlertStatusSchema } from "./alerts.validators";

const router = Router();

router.use(authenticate);

const managers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);

router.get("/", validate({ query: listAlertsQuerySchema }), controller.list);
router.get("/:id", validate({ params: alertIdParamsSchema }), controller.getById);
router.patch(
  "/:id/status",
  managers,
  auditTrail("Alert"),
  validate({ params: alertIdParamsSchema, body: updateAlertStatusSchema }),
  controller.updateStatus
);

export default router;

import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./allocation.controller";
import { allocationHistoryQuerySchema, driverIdParamsSchema, recomputeAllocationSchema } from "./allocation.validators";

const router = Router();

router.use(authenticate);

const managers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);

router.get("/me/current", controller.getMyCurrent);
router.get("/:driverId/current", validate({ params: driverIdParamsSchema }), controller.getCurrent);
router.get(
  "/:driverId/history",
  validate({ params: driverIdParamsSchema, query: allocationHistoryQuerySchema }),
  controller.getHistory
);
router.post(
  "/:driverId/recompute",
  managers,
  auditTrail("FuelAllocation"),
  validate({ params: driverIdParamsSchema, body: recomputeAllocationSchema }),
  controller.recompute
);

export default router;

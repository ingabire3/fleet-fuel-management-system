import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./fuel-requests.controller";
import {
  createFuelRequestSchema,
  decisionSchema,
  fuelRequestIdParamsSchema,
  listFuelRequestsQuerySchema,
} from "./fuel-requests.validators";

const router = Router();

router.use(authenticate);

const fleetManagers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);
// FLEET_MANAGER covers Finance responsibilities — both roles can do finance-stage approvals
const financeOfficers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);
const drivers = authorize(UserRole.DRIVER);

router.get("/", validate({ query: listFuelRequestsQuerySchema }), controller.list);
router.get("/:id", validate({ params: fuelRequestIdParamsSchema }), controller.getById);

router.post("/", drivers, auditTrail("FuelRequest"), validate({ body: createFuelRequestSchema }), controller.create);

router.patch(
  "/:id/fleet-manager-decision",
  fleetManagers,
  auditTrail("FuelRequest"),
  validate({ params: fuelRequestIdParamsSchema, body: decisionSchema }),
  controller.fleetManagerDecision
);

router.patch(
  "/:id/finance-decision",
  financeOfficers,
  auditTrail("FuelRequest"),
  validate({ params: fuelRequestIdParamsSchema, body: decisionSchema }),
  controller.financeDecision
);

router.patch(
  "/:id/cancel",
  drivers,
  auditTrail("FuelRequest"),
  validate({ params: fuelRequestIdParamsSchema }),
  controller.cancel
);

export default router;

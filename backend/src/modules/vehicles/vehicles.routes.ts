import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./vehicles.controller";
import {
  assignDriverSchema,
  createVehicleSchema,
  listVehiclesQuerySchema,
  updateVehicleSchema,
  vehicleIdParamsSchema,
} from "./vehicles.validators";

const router = Router();

router.use(authenticate);

const manage = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);
const staff = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);
// All authenticated users can list — service layer enforces driver sees only their vehicle
router.get("/", validate({ query: listVehiclesQuerySchema }), controller.list);
router.get("/me", controller.getMine);
router.get("/:id", validate({ params: vehicleIdParamsSchema }), controller.getById);

router.post("/", manage, auditTrail("Vehicle"), validate({ body: createVehicleSchema }), controller.create);
router.patch(
  "/:id",
  manage,
  auditTrail("Vehicle"),
  validate({ params: vehicleIdParamsSchema, body: updateVehicleSchema }),
  controller.update
);
router.patch(
  "/:id/assign-driver",
  manage,
  auditTrail("Vehicle"),
  validate({ params: vehicleIdParamsSchema, body: assignDriverSchema }),
  controller.assignDriver
);
router.delete("/:id", manage, auditTrail("Vehicle"), validate({ params: vehicleIdParamsSchema }), controller.remove);

export default router;

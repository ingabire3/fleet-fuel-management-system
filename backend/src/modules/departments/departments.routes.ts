import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./departments.controller";
import { createDepartmentSchema, departmentIdParamsSchema, updateDepartmentSchema } from "./departments.validators";

const router = Router();

router.use(authenticate);

const manage = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);

router.get("/", controller.list);
router.get("/:id", validate({ params: departmentIdParamsSchema }), controller.getById);

router.post("/", manage, auditTrail("Department"), validate({ body: createDepartmentSchema }), controller.create);
router.patch(
  "/:id",
  manage,
  auditTrail("Department"),
  validate({ params: departmentIdParamsSchema, body: updateDepartmentSchema }),
  controller.update
);
router.delete("/:id", manage, auditTrail("Department"), validate({ params: departmentIdParamsSchema }), controller.remove);

export default router;

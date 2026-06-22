import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./settings.controller";
import { settingKeyParamsSchema, updateSettingSchema } from "./settings.validators";

const router = Router();

router.use(authenticate);

const manage = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);

router.get("/", manage, controller.list);
router.put(
  "/:key",
  manage,
  auditTrail("SystemSetting"),
  validate({ params: settingKeyParamsSchema, body: updateSettingSchema }),
  controller.update
);

export default router;

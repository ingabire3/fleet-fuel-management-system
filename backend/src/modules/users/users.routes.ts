import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./users.controller";
import * as permissionsController from "./permissions.controller";
import {
  createUserSchema,
  listUsersQuerySchema,
  updateLocationSchema,
  updateStipendSchema,
  updateUserSchema,
  userIdParamsSchema,
} from "./users.validators";
import {
  grantPermissionSchema,
  permissionParamsSchema,
  userIdParamsSchema as permUserIdSchema,
} from "./permissions.validators";

const router = Router();

router.use(authenticate);

const staff = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);
const managers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);
const stipendManagers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);
const superAdmin = authorize(UserRole.SUPER_ADMIN);
const driversOnly = authorize(UserRole.DRIVER);

router.get("/", staff, validate({ query: listUsersQuerySchema }), controller.list);
router.get("/:id", validate({ params: userIdParamsSchema }), controller.getById);
router.get(
  "/:id/stipend-history",
  validate({ params: userIdParamsSchema, query: listUsersQuerySchema }),
  controller.getStipendHistory
);

router.post("/", managers, auditTrail("User"), validate({ body: createUserSchema }), controller.create);

router.patch(
  "/:id",
  managers,
  auditTrail("User"),
  validate({ params: userIdParamsSchema, body: updateUserSchema }),
  controller.update
);
router.patch(
  "/:id/approve",
  managers,
  auditTrail("User"),
  validate({ params: userIdParamsSchema }),
  controller.approve
);
router.patch(
  "/:id/location",
  auditTrail("User"),
  validate({ params: userIdParamsSchema, body: updateLocationSchema }),
  controller.updateLocation
);
router.patch(
  "/:id/stipend",
  stipendManagers,
  auditTrail("User"),
  validate({ params: userIdParamsSchema, body: updateStipendSchema }),
  controller.updateStipend
);

router.delete("/:id", managers, auditTrail("User"), validate({ params: userIdParamsSchema }), controller.remove);

// Driver profile completion (first-time setup)
router.patch(
  "/me/complete-profile",
  driversOnly,
  auditTrail("User"),
  validate({ body: updateLocationSchema }),
  controller.completeProfile
);

// Permission management (SA only for grant/revoke; staff can view own/target)
router.get("/:id/permissions", staff, validate({ params: permUserIdSchema }), permissionsController.list);
router.post(
  "/:id/permissions",
  superAdmin,
  auditTrail("UserPermission"),
  validate({ params: permUserIdSchema, body: grantPermissionSchema }),
  permissionsController.grant
);
router.delete(
  "/:id/permissions/:permission",
  superAdmin,
  auditTrail("UserPermission"),
  validate({ params: permissionParamsSchema }),
  permissionsController.revoke
);

export default router;

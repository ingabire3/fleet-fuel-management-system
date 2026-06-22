import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./approved-routes.controller";
import {
  createApprovedRouteSchema,
  listApprovedRoutesQuerySchema,
  routeIdParamsSchema,
  routeTripParamsSchema,
  updateApprovedRouteSchema,
} from "./approved-routes.validators";

const router = Router();

router.use(authenticate);

const managers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);

router.get("/", validate({ query: listApprovedRoutesQuerySchema }), controller.list);
router.get("/:id", validate({ params: routeIdParamsSchema }), controller.getById);
router.get("/:id/comparison/:tripId", validate({ params: routeTripParamsSchema }), controller.getComparison);

router.post("/", managers, auditTrail("ApprovedRoute"), validate({ body: createApprovedRouteSchema }), controller.create);
router.patch(
  "/:id",
  managers,
  auditTrail("ApprovedRoute"),
  validate({ params: routeIdParamsSchema, body: updateApprovedRouteSchema }),
  controller.update
);
router.delete("/:id", managers, auditTrail("ApprovedRoute"), validate({ params: routeIdParamsSchema }), controller.remove);

export default router;

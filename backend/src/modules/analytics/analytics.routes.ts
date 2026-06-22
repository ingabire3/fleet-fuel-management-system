import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { validate } from "../../middleware/validate";
import * as controller from "./analytics.controller";
import { driverIdParamsSchema, periodQuerySchema } from "./analytics.validators";

const router = Router();

router.use(authenticate);

const staff = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);

router.get("/drivers/me/summary", validate({ query: periodQuerySchema }), controller.mySummary);
router.get("/drivers/:id/summary", validate({ params: driverIdParamsSchema, query: periodQuerySchema }), controller.driverSummary);
router.get("/fleet/summary", staff, validate({ query: periodQuerySchema }), controller.fleetSummary);

export default router;

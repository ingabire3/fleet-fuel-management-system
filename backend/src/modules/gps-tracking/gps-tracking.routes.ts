import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { validate } from "../../middleware/validate";
import * as controller from "./gps-tracking.controller";
import { addWaypointSchema, endTripSchema, listTripsQuerySchema, startTripSchema, tripIdParamsSchema } from "./gps-tracking.validators";

const router = Router();

router.use(authenticate);

const staff = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);
const drivers = authorize(UserRole.DRIVER);

router.get("/live-positions", staff, controller.livePositions);
router.get("/", validate({ query: listTripsQuerySchema }), controller.list);
router.get("/:id", validate({ params: tripIdParamsSchema }), controller.getById);

router.post("/", drivers, validate({ body: startTripSchema }), controller.start);
router.post("/:id/waypoints", drivers, validate({ params: tripIdParamsSchema, body: addWaypointSchema }), controller.addWaypoint);
router.patch("/:id/end", drivers, validate({ params: tripIdParamsSchema, body: endTripSchema }), controller.end);
router.patch("/:id/cancel", drivers, validate({ params: tripIdParamsSchema }), controller.cancel);

export default router;

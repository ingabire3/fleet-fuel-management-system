import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { validate } from "../../middleware/validate";
import * as controller from "./notifications.controller";
import {
  deviceIdParamsSchema,
  listNotificationsQuerySchema,
  notificationIdParamsSchema,
  registerDeviceTokenSchema,
} from "./notifications.validators";

const router = Router();

router.use(authenticate);

router.get("/", validate({ query: listNotificationsQuerySchema }), controller.list);
router.patch("/read-all", controller.markAllAsRead);
router.patch("/:id/read", validate({ params: notificationIdParamsSchema }), controller.markAsRead);
router.post("/devices", validate({ body: registerDeviceTokenSchema }), controller.registerDevice);
router.delete("/devices/:deviceId", validate({ params: deviceIdParamsSchema }), controller.unregisterDevice);

export default router;

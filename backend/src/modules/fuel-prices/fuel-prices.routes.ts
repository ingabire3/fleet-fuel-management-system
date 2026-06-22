import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./fuel-prices.controller";
import { createFuelPriceSchema, listFuelPricesQuerySchema } from "./fuel-prices.validators";

const router = Router();

router.use(authenticate);

const writers = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER, UserRole.FINANCE_OFFICER);

router.get("/", validate({ query: listFuelPricesQuerySchema }), controller.list);
router.post("/", writers, auditTrail("FuelPrice"), validate({ body: createFuelPriceSchema }), controller.create);

export default router;

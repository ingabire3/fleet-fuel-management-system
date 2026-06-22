import { Router } from "express";
import { UserRole } from "@prisma/client";
import { authenticate } from "../../middleware/authenticate";
import { authorize } from "../../middleware/authorize";
import { auditTrail } from "../../middleware/auditTrail";
import { validate } from "../../middleware/validate";
import * as controller from "./fuel-transactions.controller";
import { createTransactionSchema, listTransactionsQuerySchema, transactionIdParamsSchema } from "./fuel-transactions.validators";

const router = Router();

router.use(authenticate);

const recorders = authorize(UserRole.SUPER_ADMIN, UserRole.FLEET_MANAGER);

router.get("/", validate({ query: listTransactionsQuerySchema }), controller.list);
router.get("/:id", validate({ params: transactionIdParamsSchema }), controller.getById);
router.post("/", recorders, auditTrail("FuelTransaction"), validate({ body: createTransactionSchema }), controller.create);

export default router;

import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { authRateLimiter } from "../../middleware/rateLimiter";
import { validate } from "../../middleware/validate";
import * as controller from "./auth.controller";
import {
  loginSchema,
  logoutSchema,
  passwordResetConfirmSchema,
  passwordResetRequestSchema,
  passwordResetVerifySchema,
  refreshSchema,
  registerSchema,
  revokeSessionParamsSchema,
  verifyLoginOtpSchema,
} from "./auth.validators";

const router = Router();

router.post("/register", authRateLimiter, validate({ body: registerSchema }), controller.register);
router.post("/login", authRateLimiter, validate({ body: loginSchema }), controller.login);
router.post("/login/verify-otp", authRateLimiter, validate({ body: verifyLoginOtpSchema }), controller.verifyLoginOtp);
router.post("/refresh", authRateLimiter, validate({ body: refreshSchema }), controller.refresh);
router.post("/logout", validate({ body: logoutSchema }), controller.logout);
router.post("/logout-all", authenticate, controller.logoutAll);

router.post(
  "/password-reset/request",
  authRateLimiter,
  validate({ body: passwordResetRequestSchema }),
  controller.requestPasswordReset
);
router.post(
  "/password-reset/verify",
  authRateLimiter,
  validate({ body: passwordResetVerifySchema }),
  controller.verifyPasswordResetOtp
);
router.post(
  "/password-reset/confirm",
  authRateLimiter,
  validate({ body: passwordResetConfirmSchema }),
  controller.confirmPasswordReset
);

router.get("/me", authenticate, controller.me);
router.get("/sessions", authenticate, controller.getSessions);
router.delete("/sessions/:id", authenticate, validate({ params: revokeSessionParamsSchema }), controller.revokeSession);

export default router;

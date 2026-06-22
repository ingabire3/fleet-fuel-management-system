import cors from "cors";
import express, { Express } from "express";
import helmet from "helmet";
import swaggerUi from "swagger-ui-express";
import { env } from "./config/env";
import { openapiSpec } from "./config/swagger";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler";
import { apiRateLimiter } from "./middleware/rateLimiter";
import { requestLogger } from "./middleware/requestLogger";
import alertsRoutes from "./modules/alerts/alerts.routes";
import analyticsRoutes from "./modules/analytics/analytics.routes";
import authRoutes from "./modules/auth/auth.routes";
import allocationsRoutes from "./modules/fuel-allocation/allocation.routes";
import departmentsRoutes from "./modules/departments/departments.routes";
import fuelPricesRoutes from "./modules/fuel-prices/fuel-prices.routes";
import fuelRequestsRoutes from "./modules/fuel-requests/fuel-requests.routes";
import fuelTransactionsRoutes from "./modules/fuel-transactions/fuel-transactions.routes";
import gpsTrackingRoutes from "./modules/gps-tracking/gps-tracking.routes";
import notificationsRoutes from "./modules/notifications/notifications.routes";
import approvedRoutesRoutes from "./modules/routes-approved/approved-routes.routes";
import auditRoutes from "./modules/audit/audit.routes";
import settingsRoutes from "./modules/settings/settings.routes";
import usersRoutes from "./modules/users/users.routes";
import vehiclesRoutes from "./modules/vehicles/vehicles.routes";

export function createApp(): Express {
  const app = express();

  // CSP disabled: this is a JSON API, and a strict default CSP breaks the Swagger UI bundle at /api-docs.
  app.use(helmet({ contentSecurityPolicy: false }));
  const allowedOrigins = env.CORS_ORIGIN.split(",").map((origin) => origin.trim());
  app.use(
    cors({
      origin: allowedOrigins.includes("*") ? "*" : allowedOrigins,
      credentials: !allowedOrigins.includes("*"),
    })
  );
  app.use(express.json());
  app.use(requestLogger);
  app.use(apiRateLimiter);

  app.get("/health", (_req, res) => res.status(200).json({ status: "ok" }));

  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(openapiSpec));

  app.use(`${env.API_PREFIX}/auth`, authRoutes);
  app.use(`${env.API_PREFIX}/users`, usersRoutes);
  app.use(`${env.API_PREFIX}/departments`, departmentsRoutes);
  app.use(`${env.API_PREFIX}/vehicles`, vehiclesRoutes);
  app.use(`${env.API_PREFIX}/fuel-prices`, fuelPricesRoutes);
  app.use(`${env.API_PREFIX}/settings`, settingsRoutes);
  app.use(`${env.API_PREFIX}/allocations`, allocationsRoutes);
  app.use(`${env.API_PREFIX}/fuel-transactions`, fuelTransactionsRoutes);
  app.use(`${env.API_PREFIX}/fuel-requests`, fuelRequestsRoutes);
  app.use(`${env.API_PREFIX}/gps`, gpsTrackingRoutes);
  app.use(`${env.API_PREFIX}/approved-routes`, approvedRoutesRoutes);
  app.use(`${env.API_PREFIX}/alerts`, alertsRoutes);
  app.use(`${env.API_PREFIX}/analytics`, analyticsRoutes);
  app.use(`${env.API_PREFIX}/notifications`, notificationsRoutes);
  app.use(`${env.API_PREFIX}/audit-logs`, auditRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

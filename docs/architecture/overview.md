# Architecture Overview

```
┌─────────────────────┐
│  Flutter App         │  Web (Vercel) / Android / iOS
│  (Provider state)    │
└──────────┬───────────┘
           │ HTTPS (JWT bearer)
           ▼
┌─────────────────────┐
│  Node/Express API    │  Render
│  Zod validation       │
│  Helmet + rate limit  │
│  JWT + OTP auth       │
└──────────┬───────────┘
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐  ┌──────────────┐
│ Prisma  │  │ Firebase     │
│ ORM     │  │ Admin (FCM)  │
└────┬────┘  └──────────────┘
     ▼
┌─────────────────┐
│ PostgreSQL       │  Supabase (hosting only)
└─────────────────┘
```

## Request flow (example: driver submits a fuel request)

1. Flutter `FuelRequestService` calls `POST /api/fuel-requests` with the JWT access token.
2. Express middleware chain: `helmet` → `cors` → `express.json` → request logger (Pino) → rate limiter → route handler.
3. Route handler validates the body with a Zod schema, then calls into the fuel-requests module's service layer.
4. Service layer uses Prisma to write `FuelRequest` + read related `FuelAllocation`/`Vehicle` rows for budget checks.
5. On success, a `Notification` row is created and, if Firebase credentials are configured, an FCM push is sent to the relevant approver's registered device tokens.
6. Response returns the created request; the Flutter app updates its `Provider` state and re-renders the dashboard.

## Auth flow

`POST /api/auth/login` → if `REQUIRE_LOGIN_OTP=true` (or per-org override), responds `requiresOtp: true` with a transient token → client calls `POST /api/auth/login/verify-otp` → on success, issues `accessToken` (15m) + `refreshToken` (30d). Refresh via `POST /api/auth/refresh`; sessions are tracked in the `Session` table and can be revoked individually (`DELETE /api/auth/sessions/:id`) or entirely (`/auth/logout-all`).

## Role-based access

Four roles (`SUPER_ADMIN`, `FLEET_MANAGER`, `FINANCE_OFFICER`, `DRIVER`) gate both API authorization (route-level middleware) and Flutter navigation (`RoleRouter` picks `AdminShell` / `FinanceShell` / `DriverShell`).

## Why this stack

- **Prisma over raw SQL**: schema-as-code, type-safe queries, and migration history live together — useful for a 25-model domain like this one.
- **Flutter for one codebase, three platforms**: the fleet's actual users are drivers on Android phones; web is an add-on for dashboards/portfolio purposes, not the primary target.
- **Supabase for Postgres only, not as a BaaS**: keeps all business logic in one place (the Express API) rather than splitting it between Supabase functions/RLS and the backend.

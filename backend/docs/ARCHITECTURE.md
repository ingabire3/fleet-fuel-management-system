# Architecture

Self-contained Node.js/Express/Prisma/PostgreSQL backend for the Fleet Fuel
Management System. Replaces the previous Supabase backend. See [ERD.md](./ERD.md)
for the full data model.

## Stack

- **Runtime**: Node.js + TypeScript (strict mode)
- **HTTP**: Express 4, `helmet`, `cors`, `pino`/`pino-http` request logging
- **Data**: PostgreSQL via Prisma ORM (`Decimal` for money/fuel quantities)
- **Validation**: Zod schemas per module (`validate` middleware checks `body`/`params`/`query`)
- **Auth**: `jsonwebtoken` (access tokens) + bcrypt-hashed rotating refresh tokens + OTP
- **Email**: `nodemailer`
- **Push**: `firebase-admin` (Firebase Cloud Messaging)
- **Scheduling**: `node-cron`

## Request Pipeline

```
helmet → cors → express.json() → requestLogger → apiRateLimiter
  → [router-level] authenticate → authorize(...roles) → auditTrail(entity) → validate(schemas) → controller
  → errorHandler
```

- `authenticate` (`src/middleware/authenticate.ts`) verifies the JWT access token
  and attaches `req.user = { id, role, organizationId, sessionId }`.
- `authorize(...roles)` (`src/middleware/authorize.ts`) rejects if `req.user.role`
  is not in the allowed set. Service-layer ownership checks (e.g. a driver may
  only read their own records) are applied on top of this.
- `auditTrail(entityType)` (`src/middleware/auditTrail.ts`) writes an `AuditLog`
  row after successful POST/PUT/PATCH/DELETE responses (actor, action, entity,
  IP, user agent).
- `validate({ body?, params?, query? })` (`src/middleware/validate.ts`) parses
  request data through Zod schemas, replacing `req.body`/`params`/`query` with
  the parsed (typed, coerced) values.
- `errorHandler`/`notFoundHandler` (`src/middleware/errorHandler.ts`) map
  `AppError` subclasses (`src/lib/errors.ts`) to HTTP status codes.

## Auth Architecture (`src/modules/auth`)

- **Registration**: `POST /auth/register` creates a `DRIVER` user with
  `isApproved = false`. A manager must call `PATCH /users/:id/approve` before
  the driver can log in.
- **Login**: `POST /auth/login` checks email/password (bcrypt). If
  `REQUIRE_LOGIN_OTP` is enabled (global `SystemSetting`) or the request comes
  from an unrecognized `deviceId` (no matching `DeviceToken`/`LoginHistory`),
  a 6-digit OTP (bcrypt-hashed `OtpCode`, purpose `LOGIN`/`NEW_DEVICE`) is
  emailed and the client must call `POST /auth/login/verify-otp`.
- **Tokens**: a successful login/OTP-verify issues a short-lived JWT access
  token (15 min, `JWT_ACCESS_EXPIRES_IN`) and a long-lived opaque refresh token
  (30 days, `JWT_REFRESH_EXPIRES_IN`), persisted hashed in `Session`
  (`refreshToken`, `deviceId`, `expiresAt`, `revokedAt`).
- **Refresh**: `POST /auth/refresh` rotates the refresh token — the old
  `Session` row is revoked and a new one created — and issues a new access
  token.
- **Logout**: `POST /auth/logout` revokes one `Session`; `POST /auth/logout-all`
  revokes every session for the authenticated user.
- **Password reset**: OTP-gated 3-step flow
  (`/password-reset/{request,verify,confirm}`); `confirm` revokes all sessions.
- **Sessions**: `GET /auth/sessions` lists active sessions;
  `DELETE /auth/sessions/:id` revokes one (e.g. "log out this device").
- Every login attempt (success or failure) is recorded in `LoginHistory` for
  security review and new-device detection.

## RBAC

Four roles (`UserRole`): `SUPER_ADMIN`, `FLEET_MANAGER`, `FINANCE_OFFICER`,
`DRIVER`. Enforced via `authorize(...roles)` plus per-service ownership checks
(a driver can only see/act on their own records; staff are scoped to their
`organizationId`).

| Area | SUPER_ADMIN | FLEET_MANAGER | FINANCE_OFFICER | DRIVER |
|---|---|---|---|---|
| Users (CRUD, approve, role) | full | drivers only | read | self (read, location) |
| Stipend update + history | write | write | write | read own |
| Vehicles / assignment | full | full | read | read own (`/vehicles/me`) |
| Fuel prices | write | write | write | read |
| System settings | write | write | read | – |
| Fuel allocations | recompute any | recompute any | recompute any | read own |
| Fuel transactions | record | record | read | read own |
| Fuel requests | decide (stage 1+2) | stage 1 decision | stage 2 decision | submit/cancel own |
| GPS trips / live positions | read all | read all | read all | record own |
| Approved routes | manage | manage | read | read own |
| Alerts | manage | manage | manage (+ budget) | read own |
| Analytics | fleet + any driver | fleet + any driver | fleet + any driver | own only |
| Notifications / devices | self | self | self | self |

## Fuel Allocation Engine (`src/modules/fuel-allocation`)

Pure calculation in `allocation.engine.ts`'s `computeAllocation()`:

1. `oneWayKm = haversine(driver.home, driver.workSite)`
2. `distanceKm = oneWayKm * roadDistanceFactor * 2` (round trip; `ROAD_DISTANCE_FACTOR` setting, default `1.3`)
3. `baseRequirementL = distanceKm * workingDays / vehicle.fuelEfficiencyKmpl`
4. `bufferL = baseRequirementL * (bufferPercent / 100)` (`FUEL_BUFFER_PERCENT` setting, default `20`)
5. `finalAllocationL = baseRequirementL + bufferL`
6. `totalAvailableL = finalAllocationL + extraFuelGrantedL` (sum of `FINANCE_APPROVED` `FuelRequest.grantedQuantityL` for the current period)
7. `projectedCostRwf = totalAvailableL * currentFuelPrice`

`recomputeAllocationForDriver(driverId, reason, triggeredById?)`
(`allocation.service.ts`, re-exported via `allocation.hooks.ts` to avoid
circular imports) appends a new `FuelAllocation` row — history is never
mutated, only appended. It returns `null` (no-op) if the driver has no
assigned vehicle, no home/work coordinates, or no `FuelPrice` for the
vehicle's fuel type.

**Triggers** (each passes a distinct `reason`):
- Fuel price change → all drivers using that fuel type (`fuel_price_change`)
- Driver home/work location update (`location_change`)
- Vehicle (re)assignment (`vehicle_assignment`)
- Finance-approved extra fuel request → `extra_grant`
- Monthly cron on the 1st (`monthly_recompute`, `src/jobs/monthlyAllocationJob.ts`)
- Manual: `POST /allocations/:driverId/recompute` (managers only, `recomputeReason` from request body)

`GET /allocations/me/current` / `/:driverId/current` return the latest row;
`/:driverId/history` paginates all snapshots.

## Extra Fuel Request Workflow (`src/modules/fuel-requests`)

State machine (`fuel-requests.state-machine.ts`):

```
PENDING ──(Fleet Manager)──> FLEET_MANAGER_APPROVED ──(Finance)──> FINANCE_APPROVED  (terminal)
   │                              │
   ├─(FM reject)──> FLEET_MANAGER_REJECTED (terminal)
   │                              ├─(Finance reject)──> FINANCE_REJECTED (terminal)
   │                              │
   └─(driver, while PENDING/FLEET_MANAGER_APPROVED)──> CANCELLED (terminal)
```

Every transition writes a `FuelRequestApproval` row (actor, from/to status,
comment). Only the `FINANCE_APPROVED` transition affects allocations: it sets
`grantedQuantityL`, calls `recomputeAllocationForDriver(driverId, "extra_grant", actor.id)`,
and — if the resulting `projectedCostRwf` exceeds `driver.monthlyBudgetRwf` —
creates a `BUDGET_EXCEEDED` `Alert` and emits the `budget_exceeded` notification
to `SUPER_ADMIN`/`FLEET_MANAGER`/`FINANCE_OFFICER`.

## GPS Tracking & Route Detour Detection

- **`approved-routes`**: each driver has at most one `isActive` `ApprovedRoute`
  (a polyline of `ApprovedRouteWaypoint`s, e.g. the home↔work commute) with a
  `toleranceKm`. Creating a new route deactivates the previous one in the same
  transaction. `GET /:id/comparison/:tripId` compares a trip's waypoints
  against the route.
- **`gps-tracking`**: drivers start (`POST /gps`), append waypoints
  (`POST /gps/:id/waypoints`), and end (`PATCH /gps/:id/end`) trips. Only one
  `IN_PROGRESS` trip per driver is allowed.
  - On each waypoint, if the trip is linked to an `ApprovedRoute` and not yet
    flagged, `computeRouteDeviation()` (`src/lib/geo/routeDeviation.ts`)
    re-checks all waypoints against the route polyline. If any point exceeds
    `toleranceKm`, the trip is marked `isDetourFlagged = true`,
    `maxDeviationKm` is recorded, a `ROUTE_DETOUR` `Alert` is created, and the
    `route_detour` notification is sent to `SUPER_ADMIN`/`FLEET_MANAGER`.
  - On end, `distanceKm` (if not supplied) is the polyline length
    (`polylineLengthKm`) and `detourDistanceKm` is the excess over the approved
    route's `totalDistanceKm` (`computeDetourDistanceKm`).
  - `GET /gps/live-positions` (staff only) returns the latest waypoint of every
    `IN_PROGRESS` trip in the organization.

## Alerts & Analytics

- **Alerts** (`src/modules/alerts`): `AlertType` covers AI-detected issues
  (`POSSIBLE_THEFT`, `LOW_FUEL`, `RAPID_FUEL_DROP`, `UNUSUAL_ROUTE`,
  `OVER_CONSUMPTION`) as well as system-raised ones (`ROUTE_DETOUR`,
  `BUDGET_EXCEEDED`, `STIPEND_CHANGED`). Lifecycle: `OPEN → ACKNOWLEDGED/RESOLVED/DISMISSED`.
  `FINANCE_OFFICER` may only update `BUDGET_EXCEEDED` alerts; drivers are
  read-only on their own alerts.
- **Analytics** (`src/modules/analytics`):
  - `GET /analytics/drivers/:id/summary` (or `/drivers/me/summary`) — current
    allocation, fuel transaction totals by type, fuel request counts by
    status, trip distance/count, detour count, open alert count for a given
    period.
  - `GET /analytics/fleet/summary` (staff only) — vehicle status breakdown,
    active driver count, the **latest `FuelAllocation` per driver** (via
    Prisma `distinct: ['driverId']` + matching `orderBy`, i.e. `DISTINCT ON`),
    org-wide fuel transaction/request/alert totals, plus three fleet-level
    metrics:
    - `fuelUsageByDepartment` — total quantity/cost for the period, grouped
      by the transacting driver's department (`Unassigned` for drivers with
      no `departmentId`).
    - `vehicleEfficiency` — per-vehicle rated `fuelEfficiencyKmpl` vs. actual
      efficiency derived from completed `GpsTrip`s in the period
      (`distanceKm / fuelConsumedL`, `null` if no fuel consumed).
    - `monthlyTrends` — org-wide fuel quantity/cost time series for the
      6 months ending with the requested period, via `$queryRaw` with
      `date_trunc('month', ...)`.

## Notifications (`src/modules/notifications`)

Event-driven, not DB triggers. `notification-events.ts` is a catalog
(`NOTIFICATION_EVENTS`) mapping an event key to `{ category, priority,
channels, content(), email?, dedupeKey? }`. Services call:

```ts
emit(eventKey, recipientUserIds, context, { dedupeKey?, relatedId? })
```

(`notification-dispatcher.ts`):
- `IN_APP` channel → `Notification` row written **synchronously** (deduped via
  `(userId, dedupeKey)` if provided) so the UI updates immediately.
- `EMAIL`/`PUSH` channels → a `NotificationLog` row (`status = PENDING`) is
  enqueued per recipient — the **outbox pattern**.

### Outbox worker (`src/jobs/notificationOutboxWorker.ts`)

Runs every minute via `node-cron` (`src/jobs/scheduler.ts`, started from
`server.ts`). Picks up to 50 `PENDING` (or `FAILED` with `attempts < 5`)
`NotificationLog` rows:
- `EMAIL` → `sendImmediateEmail(user.email, payload as EmailTemplate)` (nodemailer; no-ops if `SMTP_HOST` unset)
- `PUSH` → `sendPushToUser(userId, payload)` (`push.service.ts`, firebase-admin
  `sendEachForMulticast` across the user's active `DeviceToken`s; no-ops if
  Firebase credentials are unset). Tokens that FCM reports as
  unregistered/invalid are marked `isActive = false`.
- Updates `status` to `SENT`/`FAILED`, increments `attempts`, records `lastError`.

### Device tokens (`device-tokens.service.ts`)

`POST /notifications/devices` upserts a `DeviceToken` by
`(userId, deviceId)` — sets/clears the FCM `token`, `deviceType`,
`deviceName`, `lastUsedAt`, `isActive = true`. `DELETE /notifications/devices/:deviceId`
deactivates (soft-deletes) it.

## Background Jobs (`src/jobs`, `scheduler.ts`)

| Job | Schedule | Purpose |
|---|---|---|
| `notificationOutboxWorker` | every minute (`* * * * *`) | Sends queued EMAIL/PUSH notifications |
| `monthlyAllocationJob` | 1st of month, 00:05 (`5 0 1 * *`) | Recomputes every active driver's allocation for the new period |
| `sessionCleanupJob` | daily at 03:00 (`0 3 * * *`) | Deletes expired/long-revoked `Session`s and expired `RateLimitEntry` rows |

## API Summary

All routes are mounted under `API_PREFIX` (default `/api`). Unless noted,
all routes require `Authorization: Bearer <accessToken>`.

| Module | Method & Path | Access |
|---|---|---|
| **auth** | `POST /auth/register` | public |
| | `POST /auth/login` | public |
| | `POST /auth/login/verify-otp` | public |
| | `POST /auth/refresh` | public |
| | `POST /auth/logout` | public (refresh token in body) |
| | `POST /auth/logout-all` | authenticated |
| | `POST /auth/password-reset/{request,verify,confirm}` | public |
| | `GET /auth/me` | authenticated |
| | `GET /auth/sessions` | authenticated |
| | `DELETE /auth/sessions/:id` | authenticated |
| **users** | `GET /users` | SA/FM/FO |
| | `GET /users/:id`, `GET /users/:id/stipend-history` | authenticated (self or staff) |
| | `POST /users` | SA/FM |
| | `PATCH /users/:id` | SA/FM |
| | `PATCH /users/:id/approve` | SA/FM |
| | `PATCH /users/:id/location` | self or SA/FM (triggers recompute) |
| | `PATCH /users/:id/stipend` | SA/FM/FO (writes `StipendHistory`, triggers recompute) |
| | `DELETE /users/:id` | SA/FM |
| **departments** | `GET /departments`, `GET /departments/:id` | authenticated |
| | `POST/PATCH/DELETE /departments...` | SA/FM |
| **vehicles** | `GET /vehicles` | SA/FM/FO |
| | `GET /vehicles/me`, `GET /vehicles/:id` | authenticated |
| | `POST/PATCH/DELETE /vehicles...`, `PATCH /vehicles/:id/assign-driver` | SA/FM |
| **fuel-prices** | `GET /fuel-prices` | authenticated |
| | `POST /fuel-prices` | SA/FM/FO (triggers recompute for affected drivers) |
| **settings** | `GET /settings`, `PUT /settings/:key` | SA/FM |
| **allocations** | `GET /allocations/me/current` | authenticated |
| | `GET /allocations/:driverId/current`, `/history` | self or SA/FM/FO |
| | `POST /allocations/:driverId/recompute` | SA/FM/FO |
| **fuel-transactions** | `GET /fuel-transactions`, `/:id` | authenticated (own or staff) |
| | `POST /fuel-transactions` | SA/FM |
| **fuel-requests** | `GET /fuel-requests`, `/:id` | authenticated (own or staff) |
| | `POST /fuel-requests` | DRIVER |
| | `PATCH /fuel-requests/:id/fleet-manager-decision` | SA/FM |
| | `PATCH /fuel-requests/:id/finance-decision` | SA/FO |
| | `PATCH /fuel-requests/:id/cancel` | owning DRIVER |
| **gps** | `GET /gps/live-positions` | SA/FM/FO |
| | `GET /gps`, `/:id` | authenticated (own or staff) |
| | `POST /gps`, `POST /gps/:id/waypoints`, `PATCH /gps/:id/end`, `PATCH /gps/:id/cancel` | DRIVER |
| **approved-routes** | `GET /approved-routes`, `/:id`, `/:id/comparison/:tripId` | authenticated (own or staff) |
| | `POST/PATCH/DELETE /approved-routes...` | SA/FM |
| **alerts** | `GET /alerts`, `/:id` | authenticated (own or org) |
| | `PATCH /alerts/:id/status` | SA/FM/FO (FO limited to `BUDGET_EXCEEDED`) |
| **analytics** | `GET /analytics/drivers/me/summary`, `/drivers/:id/summary` | authenticated (own or staff) |
| | `GET /analytics/fleet/summary` | SA/FM/FO |
| **notifications** | `GET /notifications` | authenticated |
| | `PATCH /notifications/:id/read`, `PATCH /notifications/read-all` | authenticated |
| | `POST /notifications/devices`, `DELETE /notifications/devices/:deviceId` | authenticated |

## Soft Deletes & History

Master data (`User`, `Vehicle`, `Department`, `Organization`, `ApprovedRoute`,
`DeviceToken`) use `deletedAt` soft deletes. Append-only history tables
(`FuelAllocation`, `StipendHistory`, `LoginHistory`, `AuditLog`,
`FuelRequestApproval`, `FuelTransaction`, `TripWaypoint`,
`ApprovedRouteWaypoint`, `NotificationLog`) are never updated in place except
for status/outcome fields explicitly designed to change (e.g. `NotificationLog.status`).

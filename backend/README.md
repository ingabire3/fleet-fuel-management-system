# Fleet Fuel Management System — Backend

Node.js/Express/Prisma/PostgreSQL backend for the Fleet Fuel Management System.
See [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) for system design and the
API summary, and [docs/ERD.md](./docs/ERD.md) for the data model.

## Prerequisites

- Node.js 20+
- PostgreSQL 14+ (local install or container)

## Setup

```bash
npm install
cp .env.example .env
```

Edit `.env`:

- `DATABASE_URL` — your PostgreSQL connection string.
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_TOKEN_SECRET` — set to
  random secrets (e.g. `openssl rand -hex 32`).
- `SMTP_*` — optional. If `SMTP_HOST` is unset, emails are logged and skipped
  (useful for local dev).
- `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` —
  optional. If unset, push notifications are skipped.
- `REQUIRE_LOGIN_OTP` — set `true` to force OTP verification on every login.

## Database

```bash
npm run prisma:migrate   # apply migrations to your local database
npm run seed             # seed demo organization, users, vehicles, prices, settings
```

Seeded demo accounts (all use password `Passw0rd!`):

| Email | Role |
|---|---|
| `superadmin@fleet.rw` | SUPER_ADMIN |
| `fleetmanager@fleet.rw` | FLEET_MANAGER |
| `finance@fleet.rw` | FINANCE_OFFICER |
| `driver@fleet.rw` | DRIVER |

## Run

```bash
npm run dev     # tsx watch — auto-restarts on file changes
npm run build   # tsc compile to dist/
npm start       # run compiled dist/server.js
```

The server listens on `PORT` (default `4000`) and mounts all API routes
under `API_PREFIX` (default `/api`). A health check is available at `GET /health`.

The dev server also starts the cron scheduler (`src/jobs/scheduler.ts`):
notification outbox every minute, monthly allocation recompute on the 1st,
and daily session/rate-limit cleanup.

## Smoke Test

With the seeded data, a typical flow:

```bash
# 1. Log in
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"driver@fleet.rw","password":"Passw0rd!","deviceId":"smoke-test"}'

# 2. Use the returned accessToken for subsequent requests
TOKEN=<accessToken from step 1>

# 3. Check the driver's current fuel allocation
curl http://localhost:4000/api/allocations/me/current \
  -H "Authorization: Bearer $TOKEN"

# 4. Submit an extra fuel request
curl -X POST http://localhost:4000/api/fuel-requests \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"requestedQuantityL": 20, "purpose": "Site visit"}'
```

Then, as `fleetmanager@fleet.rw`, `PATCH /api/fuel-requests/:id/fleet-manager-decision`
with `{"approve": true}`, and as `finance@fleet.rw`,
`PATCH /api/fuel-requests/:id/finance-decision` with `{"approve": true, "grantedQuantityL": 20}`.
Re-check `GET /api/allocations/me/current` as the driver — `extraFuelGrantedL`
and `totalAvailableL` should reflect the grant.

## Project Structure

```
src/
├── config/        # env, prisma client, logger, mailer, firebase, constants
├── lib/           # geo (haversine/route deviation), pagination, errors, time, settings
├── middleware/    # authenticate, authorize, validate, auditTrail, rateLimiter, errorHandler
├── modules/       # one folder per domain (auth, users, vehicles, fuel-allocation, ...)
├── jobs/          # cron jobs + scheduler
├── app.ts         # Express app wiring
└── server.ts      # entrypoint
prisma/
├── schema.prisma
└── seed.ts
docs/
├── ERD.md
└── ARCHITECTURE.md
```

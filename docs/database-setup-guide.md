# Database Setup Guide

The system uses PostgreSQL via Prisma. Supabase is used purely as managed Postgres hosting — there is no Supabase Edge Function or RLS-based business logic; all reads/writes go through the Express API and Prisma.

## Schema

`backend/prisma/schema.prisma` defines 25 models, grouped roughly as:

- **Org/access**: `Organization`, `Department`, `User`, `UserPermission`
- **Fleet**: `Vehicle`, `FuelPrice`, `SystemSetting`, `StipendHistory`
- **Fuel flow**: `FuelAllocation`, `FuelTransaction`, `FuelRequest`, `FuelRequestApproval`
- **GPS**: `GpsTrip`, `TripWaypoint`, `ApprovedRoute`, `ApprovedRouteWaypoint`
- **Notifications/audit**: `Alert`, `AuditLog`, `Notification`, `DeviceToken`, `NotificationLog`
- **Auth**: `Session`, `OtpCode`, `LoginHistory`, `RateLimitEntry`

## Migrations

```bash
cd backend
npm run prisma:migrate     # dev: creates a new migration from schema changes
npm run prisma:deploy      # prod: applies existing migrations, no schema diffing
```

Existing migrations live in `backend/prisma/migrations/`. Never hand-edit applied migrations — add a new one instead.

## Seeding

Two seed scripts, kept deliberately separate:

- `npm run seed` (`prisma/seed.ts`) — the real organization's data. Not for public demo use.
- `npm run seed:demo` (`prisma/seed.demo.ts`) — fake "Demo Fleet Co." org with `admin@example.com` / `manager@example.com` / `driver@example.com`, password `Demo@1234`. Use this for the public-facing deployment's database.

Both are idempotent (`upsert`), safe to re-run.

## Production database (Supabase)

1. New project at supabase.com → Settings → Database → connection string (use the pooled/transaction-mode URL for serverless-style hosts).
2. Set as `DATABASE_URL` for the backend (Render env var).
3. Run `prisma:deploy` then `seed:demo` once, pointed at that URL (see [deployment-guide.md](deployment-guide.md)).
4. Supabase's free tier pauses projects after a week of inactivity — if the demo DB goes cold, restore it from the Supabase dashboard and the backend will reconnect automatically.

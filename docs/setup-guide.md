# Local Setup Guide

## Prerequisites

- Node.js 20+
- Flutter SDK (stable channel)
- PostgreSQL (local, or a Supabase project — see [database-setup-guide.md](database-setup-guide.md))

## Backend

```bash
cd backend
npm install
cp .env.example .env
```

Edit `.env`:
- `DATABASE_URL` — local Postgres or Supabase connection string
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_TOKEN_SECRET` — any random strings for local dev
- Leave `SMTP_HOST` and `FIREBASE_*` empty to disable email/push locally — OTP codes print to the server log instead

```bash
npm run prisma:migrate   # creates tables
npm run seed              # real-org-style seed (prisma/seed.ts)
# or
npm run seed:demo         # portfolio demo accounts (prisma/seed.demo.ts)
npm run dev                # starts on http://localhost:4000
```

Verify: `curl http://localhost:4000/health` → `{"status":"ok"}`. API docs at `http://localhost:4000/api-docs`.

## Frontend

```bash
cd frontend
flutter pub get
```

Run on web (Chrome), pointed at your local backend:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

Run on Android emulator (backend on host machine, emulator alias `10.0.2.2`):
```bash
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

Run on a physical device over WiFi — find your machine's LAN IP (`ipconfig` on Windows) and use that instead of `localhost`/`10.0.2.2`.

Supabase URL/anon key default to the values baked into `lib/utils/constants.dart`; override with `--dart-define=SUPABASE_URL=...` / `--dart-define=SUPABASE_ANON_KEY=...` if pointing at a different Supabase project.

## Common issues

- **CORS errors in browser console**: backend `CORS_ORIGIN` doesn't include your frontend's origin. For local dev, `.env`'s default `CORS_ORIGIN=*` should already cover this.
- **OTP not arriving**: `SMTP_HOST` is empty by default — check the backend terminal log for the code instead.
- **`prisma:migrate` fails**: confirm `DATABASE_URL` is reachable and the DB user has `CREATE` privileges.

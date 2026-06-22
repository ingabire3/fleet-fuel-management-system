# Environment Configuration Guide

## Backend (`backend/.env`, see `.env.example`)

| Variable | Required | Notes |
|---|---|---|
| `NODE_ENV` | yes | `development` \| `test` \| `production` |
| `PORT` | no | default `4000` |
| `API_PREFIX` | no | default `/api` |
| `DATABASE_URL` | yes | PostgreSQL connection string |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | yes | random strings; Render auto-generates these |
| `JWT_ACCESS_EXPIRES_IN` / `JWT_REFRESH_EXPIRES_IN` | no | default `15m` / `30d` |
| `OTP_TOKEN_SECRET` | yes | signs transient OTP tokens |
| `OTP_TTL_MINUTES` / `OTP_MAX_ATTEMPTS` | no | default `10` / `5` |
| `REQUIRE_LOGIN_OTP` | no | default `false` |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` | no | leave `SMTP_HOST` empty to disable email (OTPs log instead) |
| `FIREBASE_PROJECT_ID` / `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` | no | leave empty to disable push; see [firebase-setup-guide.md](firebase-setup-guide.md) |
| `RATE_LIMIT_WINDOW_MS` / `RATE_LIMIT_MAX` / `AUTH_RATE_LIMIT_MAX` | no | defaults `60000` / `100` / `10` |
| `CORS_ORIGIN` | yes in prod | comma-separated allowed origins, or `*` for dev only |
| `CLIENT_URL` / `API_URL` | informational | not read by the server; used for docs/README links |

## Frontend (`--dart-define` flags, no `.env` file)

Flutter Web has no native `.env` support; this project uses `--dart-define` instead, with defaults baked in for local dev:

| Flag | Read in | Default if omitted |
|---|---|---|
| `API_BASE_URL` | `lib/config/api_config.dart` | platform-specific localhost/LAN guess |
| `SUPABASE_URL` | `lib/utils/constants.dart` | project's existing Supabase URL |
| `SUPABASE_ANON_KEY` | `lib/utils/constants.dart` | project's existing anon key (public, safe to ship) |

Vercel injects these via `frontend/vercel-build.sh`, which reads them from Vercel project env vars and passes them as `--dart-define` flags during `flutter build web`.

**Important**: only the Supabase **anon/public** key belongs here. Never put a Supabase service-role key, database password, or any backend secret into a `--dart-define` flag — it ships in the compiled JS bundle and is publicly readable.

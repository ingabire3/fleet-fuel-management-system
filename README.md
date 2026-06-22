# Fleet Fuel Management System

Smart fleet management system with GPS tracking, dynamic fuel calculation, PDF reports, push notifications, OTP authentication, an analytics dashboard, and role-based access — built for a real fleet operation in Kigali, Rwanda.

**Live demo:** `<your-vercel-url>` &nbsp;|&nbsp; **API docs:** `<your-render-url>/api-docs`

> Demo server may take 30–60 seconds on first load due to free-tier hosting (Render spins down idle services).

## Demo credentials

| Role | Email | Password |
|---|---|---|
| Admin | admin@example.com | Demo@1234 |
| Fleet Manager | manager@example.com | Demo@1234 |
| Driver | driver@example.com | Demo@1234 |

Tap a role on the login screen to autofill.

## Features

- GPS route tracking with waypoint logging and map view (`flutter_map`)
- Dynamic fuel allocation based on commute distance, working days, and fuel price
- Fuel request → approval workflow with audit trail
- PDF report generation and printing
- Push notifications (Firebase Cloud Messaging): login, fuel requests, approvals, security alerts
- OTP-verified login (email-based, toggleable per org)
- Role-based access: Super Admin, Fleet Manager, Finance Officer, Driver
- Analytics dashboard with anomaly detection on fuel/odometer patterns

## Technology stack

**Frontend** — Flutter/Dart, `supabase_flutter`, `flutter_map` + `latlong2`, `fl_chart`, `provider`, `pdf`/`printing`, `google_fonts`. Targets Android, iOS, and Web.

**Backend** — Node.js, TypeScript, Express, Prisma ORM, JWT auth, bcrypt, Firebase Admin, Helmet, Zod, Pino, node-cron, Swagger (`swagger-ui-express`).

**Database** — PostgreSQL (hosted on Supabase).

**Hosting** — Backend on Render, frontend (Flutter Web) on Vercel.

## Architecture

```
Flutter App (Web/Android/iOS)
        │
        ▼
Node/Express API  ──▶  Firebase (push notifications)
        │
        ▼
   Prisma ORM
        │
        ▼
PostgreSQL (Supabase)
```

See [docs/architecture/overview.md](docs/architecture/overview.md) for details.

## Repository structure

```
backend/    Node/Express API, Prisma schema + migrations, OpenAPI spec
frontend/   Flutter app (mobile + web)
docs/       guides, architecture notes, API docs, screenshots
```

## Local setup

### Backend
```bash
cd backend
npm install
cp .env.example .env        # fill in DATABASE_URL, JWT secrets, etc.
npm run prisma:migrate
npm run seed                # or: npm run seed:demo
npm run dev                 # http://localhost:4000, docs at /api-docs
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:4000 \
  --dart-define=SUPABASE_URL=<your-supabase-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

Full instructions: [docs/setup-guide.md](docs/setup-guide.md)

## Deployment

Backend → Render, frontend → Vercel, database → Supabase Postgres. Step-by-step: [docs/deployment-guide.md](docs/deployment-guide.md)

## API documentation

OpenAPI spec at `backend/docs/openapi.yaml`, served live at `/api-docs` (Swagger UI). Reference: [docs/api/README.md](docs/api/README.md)

## Future improvements

- Real-time GPS streaming via WebSockets instead of poll-based trip sync
- Multi-tenant billing for SaaS-style fleet operators
- Offline-first mobile sync queue for poor-connectivity areas

## License

Portfolio project — not licensed for production reuse without permission.

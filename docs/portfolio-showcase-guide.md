# Portfolio Showcase Guide

How to present this project to recruiters/LinkedIn viewers.

## Links to have ready

- GitHub repo (public)
- Live demo: Vercel URL (Flutter Web build, landing page first)
- API docs: Render URL + `/api-docs`

## What to lead with

Recruiters skim. The landing page (`frontend/lib/screens/landing_screen.dart`) leads with the hero + feature chips + tech stack + demo credentials in that order — don't make them dig for "can I actually click around this."

## Screenshots checklist (`docs/screenshots/`)

- Landing page hero
- Login screen
- Admin dashboard
- Driver dashboard with fuel gauge
- GPS trip map
- Fuel request approval flow
- Analytics dashboard with a chart
- Swagger UI `/api-docs`

Capture at consistent browser width (1440px) for a clean README grid.

## Talking points for an interview

- Why Prisma + Postgres over a NoSQL choice: 25 relational models with real foreign-key constraints (org → department → user → vehicle → fuel allocation) benefit from relational integrity, not just key-value lookups.
- Why OTP is optional per-org (`REQUIRE_LOGIN_OTP` setting) rather than hardcoded: different fleet orgs have different risk tolerance/UX needs — this was a real configurability requirement, not a generic toggle.
- Why Supabase is used only as Postgres hosting, not as the backend: keeps a single source of truth for business logic (the Express API) instead of splitting auth/logic between two systems.
- Anomaly detection: `frontend/lib/utils/anomaly_detector.dart` + backend `Alert` model flag fuel-consumption or route deviations against `ApprovedRoute` data — explain the heuristic, not just "ML magic."

## Known limitations to mention proactively (shows judgment, not weakness)

- Free-tier Render cold starts (~30-60s) — explained on the landing page itself.
- Push notifications require native FCM config files not committed to the repo (by design — they're per-deployment secrets).
- Web push notifications are out of scope for the demo (browser FCM needs a service worker + web config not yet wired up); mobile builds get full push support.

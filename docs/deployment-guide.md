# Deployment Guide

Three free-tier services, wired together:

```
Vercel (Flutter Web)  →  Render (Node/Express API)  →  Supabase (PostgreSQL)
                                    │
                                    ▼
                          Firebase (push notifications)
```

## 1. Database — Supabase

1. Create a project at supabase.com (free tier).
2. Settings → Database → copy the connection string (use the **pooled** connection string for serverless-friendly hosts like Render's free plan).
3. Set it as `DATABASE_URL` in the backend env (see below). Supabase is used **only** as managed Postgres — no backend logic runs inside Supabase; Prisma owns the schema.
4. Run migrations and seed once you have a deployed (or local, pointed at the remote DB) backend:
   ```bash
   cd backend
   DATABASE_URL="<supabase-connection-string>" npm run prisma:deploy
   DATABASE_URL="<supabase-connection-string>" npm run seed:demo
   ```

## 2. Backend — Render

1. Push this repo to GitHub.
2. Render → New → Blueprint → point at the repo. Render reads [`backend/render.yaml`](../backend/render.yaml) and provisions the web service automatically.
3. Render auto-generates `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `OTP_TOKEN_SECRET` (marked `generateValue: true`). Fill in the `sync: false` vars manually in the Render dashboard:
   - `DATABASE_URL` — Supabase connection string from step 1
   - `CORS_ORIGIN` — your Vercel URL once deployed, e.g. `https://your-app.vercel.app` (comma-separate multiple origins)
   - `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` — see [firebase-setup-guide.md](firebase-setup-guide.md)
   - `SMTP_HOST`, `SMTP_USER`, `SMTP_PASS` — optional; leave blank to disable email and rely on OTP-in-logs for the demo
4. Render auto-deploys on every push to the connected branch (`autoDeployTrigger: commit` in render.yaml). No extra build hook setup needed.
5. Health check: `GET /health`. API docs: `GET /api-docs`.

Render's free web services spin down after ~15 minutes idle — first request after idle takes 30-60s to cold-start. This is the reason for the landing-page warning note.

## 3. Frontend — Vercel

1. Vercel → New Project → import the repo, set **root directory** to `frontend`.
2. Vercel reads [`frontend/vercel.json`](../frontend/vercel.json), which runs `vercel-build.sh`. That script downloads the Flutter SDK at build time (Vercel has no Flutter runtime preinstalled) and runs `flutter build web --release` with `--dart-define` flags pulled from Vercel project env vars.
3. Set these in Vercel → Project Settings → Environment Variables:
   - `API_BASE_URL` — your Render service URL, e.g. `https://fuel-fleet-backend.onrender.com`
   - `SUPABASE_URL`, `SUPABASE_ANON_KEY` — same Supabase project as the backend (anon/public key only, never the service key)
4. Auto-deploy is on by default for Vercel + GitHub integration — every push to the connected branch redeploys.
5. Once deployed, go back to Render and set `CORS_ORIGIN` to the resulting Vercel URL.

## 4. Firebase — push notifications

See [firebase-setup-guide.md](firebase-setup-guide.md). Optional: the backend runs fine without Firebase credentials (`getFirebaseApp()` degrades gracefully — push notifications are just skipped).

## Order of operations (first deploy)

1. Create Supabase project, grab `DATABASE_URL`.
2. Deploy backend to Render with that `DATABASE_URL` (leave `CORS_ORIGIN=*` temporarily).
3. Run `prisma:deploy` + `seed:demo` against the Supabase DB.
4. Deploy frontend to Vercel with `API_BASE_URL` pointing at the Render URL.
5. Update Render's `CORS_ORIGIN` to the Vercel URL, redeploy backend.

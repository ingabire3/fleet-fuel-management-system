# API Documentation

Full interactive reference: **`<API_URL>/api-docs`** (Swagger UI, served by `swagger-ui-express` from `backend/docs/openapi.yaml`).

Locally: `http://localhost:4000/api-docs`. In production: `https://fuel-fleet-backend.onrender.com/api-docs` (replace with your actual Render URL).

## Auth flow quick reference

```
POST /api/auth/login
  { "email": "admin@example.com", "password": "Demo@1234" }
  → 200 { "tokens": { "accessToken", "refreshToken" } }
  → or 200 { "requiresOtp": true, "transientToken": "..." } if OTP is enabled

POST /api/auth/login/verify-otp
  { "transientToken": "...", "code": "123456" }
  → 200 { "tokens": { "accessToken", "refreshToken" } }
```

Use `Authorization: Bearer <accessToken>` on all subsequent requests. In Swagger UI, click **Authorize** and paste the access token.

## Modules covered

| Module | Base path | Examples |
|---|---|---|
| Auth | `/api/auth` | login, OTP verify, refresh, sessions, password reset |
| Users | `/api/users` | list/approve users, role assignment |
| Departments | `/api/departments` | CRUD |
| Vehicles | `/api/vehicles` | registration, driver assignment |
| Fuel Prices | `/api/fuel-prices` | per-fuel-type pricing by effective date |
| Settings | `/api/settings` | org-level system settings |
| Allocations | `/api/allocations` | monthly fuel allocation calculation |
| Fuel Transactions | `/api/fuel-transactions` | logged fill-ups |
| Fuel Requests | `/api/fuel-requests` | request → approval workflow |
| GPS | `/api/gps` | trip start/end, waypoint logging |
| Approved Routes | `/api/approved-routes` | route allowlist for anomaly detection |
| Alerts | `/api/alerts` | anomaly/security alerts |
| Analytics | `/api/analytics` | dashboard aggregates |
| Notifications | `/api/notifications` | in-app + push notification log |
| Audit Logs | `/api/audit-logs` | admin action trail |

Every request/response shape, including error formats, is documented in `backend/docs/openapi.yaml` — that file is the source of truth; this page is a navigation aid, not a duplicate.

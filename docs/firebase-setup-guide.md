# Firebase Setup Guide

Used for push notifications: login alerts, fuel request submissions, approval decisions, and security alerts. The backend degrades gracefully without credentials — `getFirebaseApp()` returns `null` and notification sends are skipped, no crash.

## 1. Create a Firebase project

1. console.firebase.google.com → Add project (free Spark plan is enough).
2. Project settings → Service accounts → Generate new private key → downloads a JSON file.

## 2. Backend credentials

From the downloaded JSON, set on the backend (Render env vars or local `.env`):

```
FIREBASE_PROJECT_ID=<project_id>
FIREBASE_CLIENT_EMAIL=<client_email>
FIREBASE_PRIVATE_KEY="<private_key, with \n kept literal>"
```

`src/config/firebase.ts` replaces literal `\n` sequences in `FIREBASE_PRIVATE_KEY` before initializing the Admin SDK — paste the key as a single line with `\n` escapes intact (this is how Render/most dashboards store multi-line secrets anyway).

## 3. Frontend (device registration)

The Flutter app registers device tokens via `NotificationService` → `DeviceToken` model on the backend. For a web demo deployment, browser push requires a Firebase web config (apiKey, messagingSenderId, etc.) and a service worker — out of scope for the portfolio demo; mobile builds (Android/iOS) use native FCM and work once `google-services.json` / `GoogleService-Info.plist` are added to `frontend/android/app/` / `frontend/ios/Runner/` respectively (not committed — keep these out of version control).

## 4. Verify

With credentials set, trigger a notification-producing action (e.g. submit a fuel request as the driver demo account) and check the backend log — `NotificationLog` entries record send attempts/results even if no physical device is registered to receive them.

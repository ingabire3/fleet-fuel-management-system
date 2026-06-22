import admin from "firebase-admin";
import { env } from "./env";
import { logger } from "./logger";

let app: admin.app.App | null = null;

export function getFirebaseApp(): admin.app.App | null {
  if (app) return app;

  if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_CLIENT_EMAIL || !env.FIREBASE_PRIVATE_KEY) {
    logger.warn("Firebase credentials not configured - push notifications disabled");
    return null;
  }

  app = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
    }),
  });

  return app;
}

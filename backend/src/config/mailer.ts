import nodemailer from "nodemailer";
import { env } from "./env";
import { logger } from "./logger";

export const mailer = nodemailer.createTransport({
  host: env.SMTP_HOST,
  port: env.SMTP_PORT,
  secure: env.SMTP_SECURE,
  auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASS } : undefined,
});

export interface EmailMessage {
  to: string;
  subject: string;
  text?: string;
  html?: string;
}

export async function sendEmail(message: EmailMessage): Promise<void> {
  if (!env.SMTP_HOST) {
    logger.warn({ to: message.to, subject: message.subject }, "SMTP not configured - skipping email send");
    return;
  }

  await mailer.sendMail({
    from: env.SMTP_FROM,
    to: message.to,
    subject: message.subject,
    text: message.text,
    html: message.html,
  });
}

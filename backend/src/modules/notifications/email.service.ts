import { sendEmail } from "../../config/mailer";

export interface EmailTemplate {
  subject: string;
  text: string;
  html: string;
}

/** Sends a templated email immediately (bypasses the notification outbox).
 *  Used for time-sensitive messages such as OTP codes. */
export async function sendImmediateEmail(to: string, template: EmailTemplate): Promise<void> {
  await sendEmail({ to, subject: template.subject, text: template.text, html: template.html });
}

export function otpEmailTemplate(code: string, purpose: string): EmailTemplate {
  const purposeLabel: Record<string, string> = {
    LOGIN: "log in to your account",
    PASSWORD_RESET: "reset your password",
    NEW_DEVICE: "verify this new device",
    EMAIL_VERIFICATION: "verify your email address",
  };
  const action = purposeLabel[purpose] ?? "verify your identity";

  return {
    subject: `Your verification code: ${code}`,
    text: `Use this code to ${action}: ${code}. This code expires shortly. If you did not request this, please ignore this email.`,
    html: `<p>Use this code to ${action}:</p><h2>${code}</h2><p>This code expires shortly. If you did not request this, please ignore this email.</p>`,
  };
}

export function accountCreatedTemplate(fullName: string): EmailTemplate {
  return {
    subject: "Welcome to Fleet Fuel Management",
    text: `Hi ${fullName}, your account has been created and is pending approval. You will be notified once it is activated.`,
    html: `<p>Hi ${fullName},</p><p>Your account has been created and is pending approval. You will be notified once it is activated.</p>`,
  };
}

export function accountApprovedTemplate(fullName: string): EmailTemplate {
  return {
    subject: "Your account has been approved",
    text: `Hi ${fullName}, your account has been approved. You can now log in.`,
    html: `<p>Hi ${fullName},</p><p>Your account has been approved. You can now log in.</p>`,
  };
}

export function passwordChangedTemplate(fullName: string): EmailTemplate {
  return {
    subject: "Your password was changed",
    text: `Hi ${fullName}, your password was just changed. If this wasn't you, contact your administrator immediately.`,
    html: `<p>Hi ${fullName},</p><p>Your password was just changed. If this wasn't you, contact your administrator immediately.</p>`,
  };
}

export function newDeviceLoginTemplate(fullName: string, deviceInfo: string): EmailTemplate {
  return {
    subject: "New device login detected",
    text: `Hi ${fullName}, we detected a login from a new device: ${deviceInfo}. If this wasn't you, contact your administrator immediately.`,
    html: `<p>Hi ${fullName},</p><p>We detected a login from a new device: <strong>${deviceInfo}</strong>.</p><p>If this wasn't you, contact your administrator immediately.</p>`,
  };
}

export function genericNotificationTemplate(title: string, message: string): EmailTemplate {
  return {
    subject: title,
    text: message,
    html: `<p>${message}</p>`,
  };
}

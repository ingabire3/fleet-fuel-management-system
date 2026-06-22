import { NotificationCategory, NotificationChannel, NotificationPriority } from "@prisma/client";
import { EmailTemplate, genericNotificationTemplate } from "./email.service";

export interface NotificationContent {
  title: string;
  message: string;
}

export interface NotificationEventDefinition<TContext = Record<string, unknown>> {
  category: NotificationCategory;
  priority: NotificationPriority;
  channels: NotificationChannel[];
  content: (ctx: TContext) => NotificationContent;
  dedupeKey?: (ctx: TContext) => string | undefined;
  email?: (ctx: TContext, content: NotificationContent) => EmailTemplate;
}

export const NOTIFICATION_EVENTS = {
  // ---- Account ----
  account_created: {
    category: NotificationCategory.ACCOUNT,
    priority: NotificationPriority.LOW,
    // Email sent directly (sendImmediateEmail) in auth/users service — no outbox duplicate
    channels: [],
    content: (_ctx: Record<string, never>) => ({
      title: "Account created",
      message: "Your account has been created and is pending approval.",
    }),
  },

  account_approved: {
    category: NotificationCategory.ACCOUNT,
    priority: NotificationPriority.MEDIUM,
    // Email sent directly — keep only IN_APP here to avoid duplicate
    channels: [NotificationChannel.IN_APP],
    content: (_ctx: Record<string, never>) => ({
      title: "Account approved",
      message: "Your account has been approved. You can now log in.",
    }),
  },

  // ---- Security ----
  password_changed: {
    category: NotificationCategory.SECURITY,
    priority: NotificationPriority.HIGH,
    // Email sent directly in auth service — keep PUSH only here
    channels: [NotificationChannel.PUSH],
    content: (_ctx: Record<string, never>) => ({
      title: "Password changed",
      message: "Your password was just changed. If this wasn't you, contact your administrator immediately.",
    }),
  },

  login_alert_new_device: {
    category: NotificationCategory.SECURITY,
    priority: NotificationPriority.HIGH,
    // Email sent directly (immediate security alert) — IN_APP only here
    channels: [NotificationChannel.IN_APP],
    content: (ctx: { deviceInfo: string }) => ({
      title: "New device login",
      message: `A login was detected from a new device: ${ctx.deviceInfo}.`,
    }),
  },

  // ---- Fuel Requests ----
  fuel_request_submitted: {
    category: NotificationCategory.FUEL_REQUEST,
    priority: NotificationPriority.MEDIUM,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { driverName: string; quantityL: number }) => ({
      title: "New fuel request",
      message: `${ctx.driverName} requested ${ctx.quantityL}L of extra fuel.`,
    }),
    email: (ctx: { driverName: string; quantityL: number }) => ({
      subject: `New Fuel Request — ${ctx.driverName}`,
      text: `${ctx.driverName} has submitted an extra fuel request for ${ctx.quantityL}L. Please log in to review and take action.`,
      html: `<p><strong>${ctx.driverName}</strong> has submitted an extra fuel request for <strong>${ctx.quantityL}L</strong>.</p><p>Please log in to review and approve or reject the request.</p>`,
    }),
  },

  fuel_request_fm_approved: {
    category: NotificationCategory.FUEL_REQUEST,
    priority: NotificationPriority.MEDIUM,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { driverName: string; quantityL: number }) => ({
      title: "Fuel request needs finance approval",
      message: `${ctx.driverName}'s request for ${ctx.quantityL}L was approved by the fleet manager and now awaits finance approval.`,
    }),
    email: (ctx: { driverName: string; quantityL: number }) => ({
      subject: `Fuel Request Awaiting Finance Approval — ${ctx.driverName}`,
      text: `${ctx.driverName}'s extra fuel request for ${ctx.quantityL}L has been approved by the Fleet Manager and now requires Finance approval. Please log in to review.`,
      html: `<p><strong>${ctx.driverName}</strong>'s extra fuel request for <strong>${ctx.quantityL}L</strong> has been approved by the Fleet Manager.</p><p>It now requires your <strong>Finance approval</strong>. Please log in to review.</p>`,
    }),
  },

  fuel_request_approved: {
    category: NotificationCategory.FUEL_REQUEST,
    priority: NotificationPriority.HIGH,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { quantityL: number }) => ({
      title: "Fuel request approved",
      message: `Your extra fuel request for ${ctx.quantityL}L has been fully approved.`,
    }),
    email: (ctx: { quantityL: number }) => ({
      subject: "Your Fuel Request Has Been Approved",
      text: `Great news! Your extra fuel request for ${ctx.quantityL}L has been fully approved. Your fuel allocation has been updated accordingly.`,
      html: `<p>Great news! Your extra fuel request for <strong>${ctx.quantityL}L</strong> has been <strong>fully approved</strong>.</p><p>Your fuel allocation has been updated accordingly.</p>`,
    }),
  },

  fuel_request_rejected: {
    category: NotificationCategory.FUEL_REQUEST,
    priority: NotificationPriority.HIGH,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { reason?: string }) => ({
      title: "Fuel request rejected",
      message: ctx.reason ? `Your extra fuel request was rejected: ${ctx.reason}` : "Your extra fuel request was rejected.",
    }),
    email: (ctx: { reason?: string }) => ({
      subject: "Your Fuel Request Has Been Rejected",
      text: `Your extra fuel request has been rejected.${ctx.reason ? ` Reason: ${ctx.reason}` : ""} Please contact your manager for more information.`,
      html: `<p>Your extra fuel request has been <strong>rejected</strong>.${ctx.reason ? `<br/><strong>Reason:</strong> ${ctx.reason}` : ""}</p><p>Please contact your Fleet Manager for more information.</p>`,
    }),
  },

  fuel_request_cancelled: {
    category: NotificationCategory.FUEL_REQUEST,
    priority: NotificationPriority.LOW,
    channels: [NotificationChannel.IN_APP, NotificationChannel.EMAIL],
    content: (ctx: { driverName: string }) => ({
      title: "Fuel request cancelled",
      message: `${ctx.driverName} cancelled their extra fuel request.`,
    }),
    email: (ctx: { driverName: string }) => ({
      subject: `Fuel Request Cancelled — ${ctx.driverName}`,
      text: `${ctx.driverName} has cancelled their extra fuel request. No further action is required.`,
      html: `<p><strong>${ctx.driverName}</strong> has cancelled their extra fuel request.</p><p>No further action is required.</p>`,
    }),
  },

  // ---- Stipend ----
  stipend_updated: {
    category: NotificationCategory.STIPEND,
    priority: NotificationPriority.HIGH,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { newAmount: string }) => ({
      title: "Fuel stipend updated",
      message: `Your monthly fuel stipend has been updated to ${ctx.newAmount} RWF.`,
    }),
    email: (ctx: { newAmount: string }) => ({
      subject: "Your Monthly Fuel Stipend Has Been Updated",
      text: `Your monthly fuel stipend has been updated to ${ctx.newAmount} RWF. If you have questions, contact your Fleet Manager or Finance Officer.`,
      html: `<p>Your monthly fuel stipend has been updated to <strong>${ctx.newAmount} RWF</strong>.</p><p>If you have questions, please contact your Fleet Manager or Finance Officer.</p>`,
    }),
  },

  // ---- Vehicle ----
  vehicle_assignment_changed: {
    category: NotificationCategory.VEHICLE,
    priority: NotificationPriority.MEDIUM,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { plateNumber: string }) => ({
      title: "Vehicle assignment changed",
      message: `You have been assigned vehicle ${ctx.plateNumber}.`,
    }),
    email: (ctx: { plateNumber: string }) => ({
      subject: "Your Vehicle Assignment Has Changed",
      text: `You have been assigned a new vehicle: ${ctx.plateNumber}. Please check the Fleet Management system for details.`,
      html: `<p>You have been assigned a new vehicle: <strong>${ctx.plateNumber}</strong>.</p><p>Please check the Fleet Management system for more details.</p>`,
    }),
  },

  // ---- Allocation ----
  allocation_recomputed: {
    category: NotificationCategory.BUDGET,
    priority: NotificationPriority.LOW,
    channels: [NotificationChannel.IN_APP],
    content: (ctx: { finalAllocationL: string; reason: string }) => ({
      title: "Fuel allocation updated",
      message: `Your monthly fuel allocation was recalculated to ${ctx.finalAllocationL}L (${ctx.reason}).`,
    }),
  },

  // ---- Budget ----
  budget_exceeded: {
    category: NotificationCategory.BUDGET,
    priority: NotificationPriority.CRITICAL,
    channels: [NotificationChannel.IN_APP, NotificationChannel.EMAIL],
    content: (ctx: { driverName: string; percentUsed: number }) => ({
      title: "Budget exceeded",
      message: `${ctx.driverName} has used ${ctx.percentUsed}% of their monthly fuel budget.`,
    }),
    email: (ctx: { driverName: string; percentUsed: number }) => ({
      subject: `Budget Exceeded — ${ctx.driverName} (${ctx.percentUsed}%)`,
      text: `Warning: ${ctx.driverName} has used ${ctx.percentUsed}% of their monthly fuel budget. Please review and take appropriate action.`,
      html: `<p><strong>Warning:</strong> <strong>${ctx.driverName}</strong> has used <strong>${ctx.percentUsed}%</strong> of their monthly fuel budget.</p><p>Please review and take appropriate action.</p>`,
    }),
  },

  // ---- Alerts ----
  ai_alert_created: {
    category: NotificationCategory.AI_ALERT,
    priority: NotificationPriority.HIGH,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
    content: (ctx: { title: string; description?: string }) => ({
      title: ctx.title,
      message: ctx.description ?? ctx.title,
    }),
  },

  route_detour: {
    category: NotificationCategory.AI_ALERT,
    priority: NotificationPriority.HIGH,
    channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH, NotificationChannel.EMAIL],
    content: (ctx: { driverName: string; deviationKm: number }) => ({
      title: "Route detour detected",
      message: `${ctx.driverName} deviated ${ctx.deviationKm.toFixed(1)}km from their approved route.`,
    }),
    email: (ctx: { driverName: string; deviationKm: number }) => ({
      subject: `Route Detour Detected — ${ctx.driverName}`,
      text: `${ctx.driverName} has deviated ${ctx.deviationKm.toFixed(1)}km from their approved route. Please investigate.`,
      html: `<p><strong>${ctx.driverName}</strong> has deviated <strong>${ctx.deviationKm.toFixed(1)}km</strong> from their approved route.</p><p>Please investigate this deviation.</p>`,
    }),
  },
} satisfies Record<string, NotificationEventDefinition<any>>;

export type NotificationEventKey = keyof typeof NOTIFICATION_EVENTS;

export function buildEmailTemplate<K extends NotificationEventKey>(
  key: K,
  content: NotificationContent,
  ctx: Parameters<(typeof NOTIFICATION_EVENTS)[K]["content"]>[0]
): EmailTemplate {
  const def = NOTIFICATION_EVENTS[key] as NotificationEventDefinition<typeof ctx>;
  if (def.email) return def.email(ctx, content);
  return genericNotificationTemplate(content.title, content.message);
}

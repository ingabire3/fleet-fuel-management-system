import { z } from "zod";

export const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(72),
  fullName: z.string().min(1).max(120),
  phone: z.string().min(1).max(30).optional(),
  employeeId: z.string().min(1).max(50).optional(),
  departmentId: z.string().uuid().optional(),
  homeAddress: z.string().max(255).optional(),
  homeLat: z.number().min(-90).max(90).optional(),
  homeLng: z.number().min(-180).max(180).optional(),
  workSiteName: z.string().max(255).optional(),
  workSiteLat: z.number().min(-90).max(90).optional(),
  workSiteLng: z.number().min(-180).max(180).optional(),
  fuelType: z.enum(["PETROL", "DIESEL", "ELECTRIC", "HYBRID"]).optional(),
});

export const deviceContextSchema = z.object({
  deviceId: z.string().max(120).optional(),
  deviceType: z.enum(["ANDROID", "IOS", "WEB", "UNKNOWN"]).optional(),
  deviceName: z.string().max(120).optional(),
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
}).merge(deviceContextSchema);

export const verifyLoginOtpSchema = z.object({
  transientToken: z.string().min(1),
  code: z.string().length(6),
}).merge(deviceContextSchema);

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
}).merge(deviceContextSchema);

export const logoutSchema = z.object({
  refreshToken: z.string().min(1),
});

export const passwordResetRequestSchema = z.object({
  email: z.string().email(),
});

export const passwordResetVerifySchema = z.object({
  email: z.string().email(),
  code: z.string().length(6),
});

export const passwordResetConfirmSchema = z.object({
  resetToken: z.string().min(1),
  newPassword: z.string().min(8).max(72),
});

export const revokeSessionParamsSchema = z.object({
  id: z.string().uuid(),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type VerifyLoginOtpInput = z.infer<typeof verifyLoginOtpSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
export type PasswordResetRequestInput = z.infer<typeof passwordResetRequestSchema>;
export type PasswordResetVerifyInput = z.infer<typeof passwordResetVerifySchema>;
export type PasswordResetConfirmInput = z.infer<typeof passwordResetConfirmSchema>;

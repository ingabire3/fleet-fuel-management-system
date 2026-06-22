/** Default values used by the fuel allocation engine and other modules.
 *  These are fallback defaults — actual values are read from SystemSetting
 *  at runtime where applicable. */
export const DEFAULTS = {
  FUEL_BUFFER_PERCENT: 20,
  DEFAULT_WORKING_DAYS: 22,
  ROAD_DISTANCE_FACTOR: 1.3,
  REQUIRE_LOGIN_OTP: false,
};

export const SETTING_KEYS = {
  FUEL_BUFFER_PERCENT: "FUEL_BUFFER_PERCENT",
  DEFAULT_WORKING_DAYS: "DEFAULT_WORKING_DAYS",
  ROAD_DISTANCE_FACTOR: "ROAD_DISTANCE_FACTOR",
  REQUIRE_LOGIN_OTP: "REQUIRE_LOGIN_OTP",
} as const;

export const DEFAULT_ORG_CODE = "DEFAULT";

export const ALERT_THRESHOLDS = {
  LOW_FUEL_PERCENT: 0.15,
  RAPID_DROP_PERCENT: 0.5,
  RAPID_DROP_LITERS: 40,
};

export const AUTH = {
  LOGIN_MAX_ATTEMPTS: 5,
  LOGIN_LOCKOUT_WINDOW_MS: 15 * 60 * 1000,
  BCRYPT_ROUNDS: 10,
};

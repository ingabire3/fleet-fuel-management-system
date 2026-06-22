const UNIT_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
};

/** Parses a duration string like "15m", "30d", "10s" into milliseconds. */
export function parseDurationMs(value: string): number {
  const match = /^(\d+)\s*(s|m|h|d)$/.exec(value.trim());
  if (!match) {
    throw new Error(`Invalid duration string: ${value}`);
  }
  const [, amount, unit] = match;
  return Number(amount) * UNIT_MS[unit];
}

export function addDuration(date: Date, duration: string): Date {
  return new Date(date.getTime() + parseDurationMs(duration));
}

export function currentPeriod(date = new Date()): { year: number; month: number } {
  return { year: date.getUTCFullYear(), month: date.getUTCMonth() + 1 };
}

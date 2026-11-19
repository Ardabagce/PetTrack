export const DAY = 86_400_000;

export function startOfDay(d: Date | string): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function addDays(d: Date | string, n: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

export function addMonths(d: Date | string, n: number): Date {
  const x = new Date(d);
  x.setMonth(x.getMonth() + n);
  return x;
}

export function addYears(d: Date | string, n: number): Date {
  const x = new Date(d);
  x.setFullYear(x.getFullYear() + n);
  return x;
}

/** Whole calendar days from a to b (b - a). */
export function daysBetween(a: Date | string, b: Date | string): number {
  return Math.round((startOfDay(b).getTime() - startOfDay(a).getTime()) / DAY);
}

export function isSameDay(a: Date | string, b: Date | string): boolean {
  return startOfDay(a).getTime() === startOfDay(b).getTime();
}

export function atTime(day: Date | string, hour: number, minute: number): Date {
  const x = new Date(day);
  x.setHours(hour, minute, 0, 0);
  return x;
}

export function startOfMonth(d: Date | string): Date {
  const x = startOfDay(d);
  x.setDate(1);
  return x;
}

export const iso = (d: Date) => d.toISOString();

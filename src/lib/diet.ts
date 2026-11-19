import { daysBetween } from './dates';
import type { DietTransition } from './types';

/** Classic gradual switch: 25% → 50% → 75% → 100% new food, spread evenly over the period. */
export function newFoodRatio(dayIndex: number, durationDays: number): number {
  if (durationDays <= 0) return 1;
  if (dayIndex < 0) return 0;
  if (dayIndex >= durationDays) return 1;
  const phase = Math.min(3, Math.floor((dayIndex / durationDays) * 4));
  return (phase + 1) * 0.25;
}

export function transitionDay(t: DietTransition, now = new Date()): number {
  return daysBetween(t.start, now);
}

export function isTransitionComplete(t: DietTransition, now = new Date()): boolean {
  return transitionDay(t, now) >= t.days;
}

/** Groups consecutive days with the same ratio, e.g. [{from:1,to:2,ratio:.25}, …]. */
export function transitionPhases(days: number): { from: number; to: number; ratio: number }[] {
  const phases: { from: number; to: number; ratio: number }[] = [];
  let start = 0;
  for (let day = 1; day <= days; day++) {
    const ratio = newFoodRatio(start, days);
    if (day === days || newFoodRatio(day, days) !== ratio) {
      phases.push({ from: start + 1, to: day, ratio });
      start = day;
    }
  }
  return phases;
}

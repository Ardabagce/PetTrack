import { addDays, daysBetween, isSameDay, startOfDay } from './dates';
import type { CheckIn, Collections, Pet, Species } from './types';

// MARK: Age & life stage

/**
 * Human-equivalent age. Dogs follow the AVMA size-adjusted chart (15 years for year one, +9 for year two,
 * then +4/+5/+6/+7 per year for small/medium/large/giant dogs). Cats: 15, then 24, then +4 per year.
 */
export function humanYears(species: Species, ageYears: number, weightKg?: number): number | undefined {
  if (ageYears < 0) return undefined;
  if (species === 'dog' || species === 'cat') {
    if (ageYears <= 1) return Math.round(ageYears * 15);
    if (ageYears <= 2) return Math.round(15 + (ageYears - 1) * 9);
    const perYear = species === 'cat' ? 4 : !weightKg || weightKg < 9 ? 4 : weightKg < 23 ? 5 : weightKg < 40 ? 6 : 7;
    return Math.round(24 + (ageYears - 2) * perYear);
  }
  return undefined;
}

export type LifeStage = 'baby' | 'junior' | 'adult' | 'mature' | 'senior';

export function lifeStage(species: Species, ageYears: number, weightKg?: number): LifeStage {
  if (ageYears < 0.5) return 'baby';
  if (ageYears < (species === 'dog' && (weightKg ?? 0) >= 23 ? 2 : 1)) return 'junior';
  const seniorAt = species === 'cat' ? 11 : !weightKg || weightKg < 9 ? 10 : weightKg < 23 ? 9 : 7;
  if (ageYears >= seniorAt) return 'senior';
  if (ageYears >= seniorAt - 3) return 'mature';
  return 'adult';
}

export const ageInYears = (birth: string, now = new Date()) => (now.getTime() - new Date(birth).getTime()) / (365.25 * 86_400_000);

// MARK: Calories & portions

export type Activity = 'low' | 'normal' | 'high';

/** Resting energy requirement in kcal/day. */
export const rer = (kg: number) => 70 * Math.pow(kg, 0.75);

/**
 * Daily energy factor (multiplier of RER), from WSAVA / AAHA nutrition guidelines.
 * Overweight pets (BCS ≥ 7) are fed for their ideal weight at a weight-loss factor.
 */
export function energyFactor(species: Species, opts: { neutered: boolean; ageYears?: number; bcs?: number; activity?: Activity }): number {
  const { neutered, ageYears = 3, bcs = 5, activity = 'normal' } = opts;
  if (bcs >= 7) return species === 'cat' ? 0.8 : 1.0;
  if (bcs <= 3) return species === 'cat' ? 1.4 : 1.8;
  if (species === 'cat') {
    if (ageYears < 1) return 2.5;
    const base = neutered ? 1.2 : 1.4;
    return activity === 'low' ? 1.0 : activity === 'high' ? base + 0.2 : base;
  }
  if (ageYears < 0.33) return 3.0;
  if (ageYears < 1) return 2.0;
  const base = neutered ? 1.6 : 1.8;
  const senior = ageYears >= 8 ? -0.2 : 0;
  return activity === 'low' ? 1.3 + senior : activity === 'high' ? 2.0 : base + senior;
}

/** Ideal weight estimate: each BCS point above 5 ≈ 10% over ideal, below 5 ≈ 10% under. */
export const idealWeight = (kg: number, bcs: number) => kg / (1 + 0.1 * (bcs - 5));

export interface PortionPlan { idealKg: number; kcalPerDay: number; gramsPerDay?: number; gramsPerMeal?: number }

export function portionPlan(input: {
  species: Species; kg: number; bcs: number; neutered: boolean; ageYears?: number; activity?: Activity; kcalPer100g?: number; meals: number;
}): PortionPlan {
  const ideal = idealWeight(input.kg, input.bcs);
  const feedWeight = input.bcs >= 7 ? ideal : input.kg;
  const kcalPerDay = rer(feedWeight) * energyFactor(input.species, input);
  const gramsPerDay = input.kcalPer100g ? (kcalPerDay / input.kcalPer100g) * 100 : undefined;
  return {
    idealKg: Math.round(ideal * 10) / 10,
    kcalPerDay: Math.round(kcalPerDay),
    gramsPerDay: gramsPerDay ? Math.round(gramsPerDay) : undefined,
    gramsPerMeal: gramsPerDay && input.meals > 0 ? Math.round(gramsPerDay / input.meals) : undefined,
  };
}

export const BCS_LABELS: Record<number, { title: string; hint: string }> = {
  1: { title: 'Emaciated', hint: 'Ribs, spine and hip bones visible from a distance. No body fat.' },
  2: { title: 'Very thin', hint: 'Ribs, spine and hip bones easily visible. Minimal muscle.' },
  3: { title: 'Thin', hint: 'Ribs easily felt and may be visible. Obvious waist and tummy tuck.' },
  4: { title: 'Lean', hint: 'Ribs easily felt with a slight fat cover. Waist clearly visible from above.' },
  5: { title: 'Ideal', hint: 'Ribs felt without excess fat. Waist behind the ribs, belly tucked up from the side.' },
  6: { title: 'Slightly heavy', hint: 'Ribs felt with a little extra fat. Waist visible but not prominent.' },
  7: { title: 'Overweight', hint: 'Ribs hard to feel under fat. Waist barely visible, fat on lower back.' },
  8: { title: 'Obese', hint: 'Ribs not felt without firm pressure. No waist, belly may hang.' },
  9: { title: 'Severely obese', hint: 'Heavy fat over chest, spine and tail base. Belly clearly distended.' },
};

// MARK: Daily check-in pattern alerts

export interface WellnessAlert { id: string; level: 'watch' | 'vet'; text: string; values?: Record<string, string | number> }

/** Looks at the last days of check-ins and flags patterns worth acting on. Texts are English source strings. */
export function checkinAlerts(checkins: CheckIn[], now = new Date()): WellnessAlert[] {
  const recent = checkins.filter((c) => new Date(c.date) >= addDays(startOfDay(now), -6)).sort((a, b) => b.date.localeCompare(a.date));
  const lastTwo = recent.slice(0, 2);
  const alerts: WellnessAlert[] = [];
  const consecutive = lastTwo.length === 2 && daysBetween(lastTwo[1].date, lastTwo[0].date) <= 1;
  if (consecutive && lastTwo.every((c) => c.appetite <= 2)) alerts.push({ id: 'appetite', level: 'watch', text: 'Low appetite logged two days in a row.' });
  if (consecutive && lastTwo.every((c) => c.stool === 'diarrhea')) alerts.push({ id: 'diarrhea', level: 'vet', text: 'Diarrhea logged two days in a row. If you are concerned, contact your vet.' });
  const vomits = recent.filter((c) => c.vomit).length;
  if (vomits >= 2) alerts.push({ id: 'vomit', level: vomits >= 3 ? 'vet' : 'watch', text: 'Vomiting logged {{a}} times this week.', values: { a: vomits } });
  if (recent.length >= 4) {
    const avg = (xs: CheckIn[]) => xs.reduce((s, c) => s + c.energy, 0) / xs.length;
    if (avg(recent.slice(0, 2)) <= avg(recent.slice(2)) - 1.5) alerts.push({ id: 'energy', level: 'watch', text: 'Energy logged lower than earlier this week.' });
  }
  if (lastTwo[0]?.stool === 'none' && lastTwo[1]?.stool === 'none' && consecutive) alerts.push({ id: 'constipation', level: 'watch', text: 'No stool logged for two days.' });
  return alerts;
}

export const checkinToday = (checkins: CheckIn[], now = new Date()) => checkins.find((c) => isSameDay(c.date, now));

// MARK: Health score

export interface ScorePart { id: string; label: string; points: number; max: number; tip?: string }

/** 0–100 score from records the owner keeps anyway. Each part explains how to gain points. */
export function healthScore(data: Collections, pet: Pet, now = new Date()): { score: number; parts: ScorePart[] } {
  const mine = <T extends { petId: string }>(xs: T[]) => xs.filter((x) => x.petId === pet.id);
  const parts: ScorePart[] = [];

  const vaccines = mine(data.vaccinations);
  const overdue = vaccines.filter((v) => v.nextDue && new Date(v.nextDue) < startOfDay(now)).length;
  parts.push({
    id: 'vaccines', label: 'Vaccines', max: 25,
    points: vaccines.length === 0 ? 10 : Math.max(0, 25 - overdue * 10),
    tip: vaccines.length === 0 ? 'Add your pet’s vaccinations.' : overdue ? 'Book the overdue vaccine.' : undefined,
  });

  const lastBcs = mine(data.bcs).sort((a, b) => b.date.localeCompare(a.date))[0];
  const weights = mine(data.weights).sort((a, b) => b.date.localeCompare(a.date));
  const recentWeight = weights[0] && daysBetween(weights[0].date, now) <= 45;
  const bcsPoints = !lastBcs ? 8 : lastBcs.score >= 4 && lastBcs.score <= 5 ? 20 : lastBcs.score === 6 || lastBcs.score === 3 ? 12 : 5;
  parts.push({
    id: 'weight', label: 'Body condition', max: 20, points: Math.min(20, bcsPoints + (recentWeight ? 0 : -3) + (lastBcs ? 0 : recentWeight ? 4 : 0)),
    tip: !lastBcs ? 'Do a 1-minute body condition check.' : lastBcs.score >= 6 ? 'Use the portion calculator to reach the ideal weight.' : !recentWeight ? 'Weigh your pet – it has been a while.' : undefined,
  });

  const slots = mine(data.slots).filter((s) => s.enabled && s.kind === 'meal').length;
  const meals7 = mine(data.logs).filter((l) => l.kind === 'meal' && new Date(l.date) >= addDays(now, -7)).length;
  const consistency = slots ? Math.min(1, meals7 / (slots * 7)) : meals7 > 0 ? 0.7 : 0.3;
  parts.push({ id: 'feeding', label: 'Feeding routine', max: 20, points: Math.round(consistency * 20), tip: consistency < 0.7 ? 'Tick off meals to keep the routine visible.' : undefined });

  const checkins = mine(data.checkins);
  const alerts = checkinAlerts(checkins, now);
  const checked = checkins.filter((c) => new Date(c.date) >= addDays(now, -7)).length;
  const openCases = mine(data.symptomCases).filter((c) => !c.resolved).length;
  parts.push({
    id: 'wellbeing', label: 'Wellbeing', max: 20,
    points: Math.max(0, Math.min(20, 8 + checked * 2 - alerts.length * 5 - openCases * 3)),
    tip: alerts.length ? 'Check today’s wellness alerts.' : checked < 4 ? 'Do the daily check-in – it takes 10 seconds.' : undefined,
  });

  const overdueReminders = mine(data.reminders).filter((r) => !r.done && new Date(r.due) < addDays(now, -1)).length;
  parts.push({ id: 'care', label: 'Care reminders', max: 15, points: Math.max(0, 15 - overdueReminders * 5), tip: overdueReminders ? 'Catch up on overdue reminders.' : undefined });

  return { score: parts.reduce((s, p) => s + p.points, 0), parts };
}

// MARK: Unit conversion

export const CONVERSIONS = [
  { id: 'mass', from: 'kg', to: 'lb', factor: 2.20462262 },
  { id: 'small', from: 'g', to: 'oz', factor: 0.0352739619 },
  { id: 'volume', from: 'ml', to: 'cup', factor: 1 / 236.588 },
  { id: 'fluid', from: 'ml', to: 'fl oz', factor: 0.033814 },
] as const;

export const cToF = (c: number) => c * 9 / 5 + 32;
export const fToC = (f: number) => (f - 32) * 5 / 9;

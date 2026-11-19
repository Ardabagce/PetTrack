import { describe, expect, it } from '@jest/globals';
import { addDays } from '../dates';
import { checkinAlerts, energyFactor, humanYears, idealWeight, lifeStage, portionPlan, rer, cToF } from '../wellness';
import type { CheckIn } from '../types';

describe('age', () => {
  it('converts dog and cat ages', () => {
    expect(humanYears('dog', 1)).toBe(15);
    expect(humanYears('dog', 2)).toBe(24);
    expect(humanYears('dog', 3, 30)).toBe(30);
    expect(humanYears('cat', 5)).toBe(36);
    expect(humanYears('rabbit', 3)).toBeUndefined();
  });
  it('knows senior large dogs earlier', () => {
    expect(lifeStage('dog', 8, 35)).toBe('senior');
    expect(lifeStage('dog', 8, 7)).toBe('mature');
    expect(lifeStage('cat', 0.3)).toBe('baby');
  });
});

describe('calories', () => {
  it('computes RER and MER', () => {
    expect(Math.round(rer(10))).toBe(394);
    expect(energyFactor('dog', { neutered: true })).toBe(1.6);
    expect(energyFactor('cat', { neutered: true, bcs: 8 })).toBe(0.8);
  });
  it('feeds overweight pets for their ideal weight', () => {
    expect(Math.round(idealWeight(33, 7) * 10) / 10).toBe(27.5);
    const plan = portionPlan({ species: 'dog', kg: 33, bcs: 7, neutered: true, kcalPer100g: 360, meals: 2 });
    expect(plan.idealKg).toBe(27.5);
    expect(plan.kcalPerDay).toBe(Math.round(rer(27.5)));
    expect(plan.gramsPerMeal).toBe(Math.round(plan.gramsPerDay! / 2));
  });
});

describe('check-in alerts', () => {
  const day = (n: number, extra: Partial<CheckIn>): CheckIn => ({ id: String(n), petId: 'p', date: addDays(new Date(), -n).toISOString(), energy: 4, appetite: 4, stool: 'normal', vomit: false, note: '', ...extra });
  it('flags two days of low appetite and diarrhea', () => {
    const ids = checkinAlerts([day(0, { appetite: 1, stool: 'diarrhea' }), day(1, { appetite: 2, stool: 'diarrhea' })]).map((a) => a.id);
    expect(ids).toEqual(['appetite', 'diarrhea']);
  });
  it('stays quiet for a normal week', () => {
    expect(checkinAlerts([0, 1, 2, 3, 4].map((n) => day(n, {})))).toEqual([]);
  });
  it('counts vomiting', () => {
    expect(checkinAlerts([day(0, { vomit: true }), day(3, { vomit: true }), day(5, { vomit: true })])[0]).toMatchObject({ id: 'vomit', level: 'vet' });
  });
});

it('converts temperature', () => expect(cToF(38.5)).toBeCloseTo(101.3, 1));

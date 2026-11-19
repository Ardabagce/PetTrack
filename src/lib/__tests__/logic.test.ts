import { describe, it, expect } from "@jest/globals";
import { newFoodRatio, transitionPhases } from '../diet';
import { amountIn, normalizeNumber, parseReport, weightIn, firstDate } from '../parser';
import { destination, stepState, travelSteps } from '../travel';
import { searchFoods, levelFor, FOOD_ITEMS } from '../foodSafety';
import { addDays, daysBetween } from '../dates';

describe('diet transition', () => {
  it('follows 25/50/75/100 over 7 days', () => {
    expect([0, 1, 2, 3, 4, 5, 6, 7].map((d) => newFoodRatio(d, 7))).toEqual([0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1]);
  });
  it('groups phases', () => {
    expect(transitionPhases(7)).toEqual([
      { from: 1, to: 2, ratio: 0.25 }, { from: 3, to: 4, ratio: 0.5 }, { from: 5, to: 6, ratio: 0.75 }, { from: 7, to: 7, ratio: 1 },
    ]);
  });
});

describe('report parser', () => {
  it('reads an English invoice', () => {
    const r = parseReport(`Riverside Animal Clinic
Dr. Emma Hart
Date: 03/14/2026
Reason for visit: Itchy ears
Weight: 28.4 kg
Diagnosis: Otitis externa
Treatment: Ear drops twice daily for 10 days
Rabies vaccine administered
Next appointment: 04/14/2026
Subtotal 120.00
Total due $145.50`, 'US');
    expect(r.reason).toBe('Itchy ears');
    expect(r.diagnosis).toBe('Otitis externa');
    expect(r.treatment).toBe('Ear drops twice daily for 10 days');
    expect(r.weightKg).toBe(28.4);
    expect(r.totalCost).toBe(145.5);
    expect(r.currency).toBe('USD');
    expect(r.vaccines).toEqual(['Rabies']);
    expect(r.clinic).toBe('Riverside Animal Clinic');
    expect(r.vet).toBe('Dr. Emma Hart');
    expect(r.visitDate?.getMonth()).toBe(2);
    expect(r.visitDate?.getDate()).toBe(14);
    expect(r.followUp?.getMonth()).toBe(3);
  });
  it('reads a German report', () => {
    const r = parseReport(`Tierarztpraxis am Park
Datum: 14.03.2026
Grund: Lahmheit hinten links
Gewicht: 12,6 kg
Diagnose: Zerrung
Behandlung: Schonung, Schmerzmittel 5 Tage
Tollwut, SHPPi geimpft
Gesamtbetrag: 1.234,50 €`, 'DE');
    expect(r.clinic).toBe('Tierarztpraxis am Park');
    expect(r.reason).toBe('Lahmheit hinten links');
    expect(r.diagnosis).toBe('Zerrung');
    expect(r.weightKg).toBe(12.6);
    expect(r.totalCost).toBe(1234.5);
    expect(r.currency).toBe('EUR');
    expect(new Set(r.vaccines)).toEqual(new Set(['Rabies', 'DHPP']));
    expect(r.visitDate?.getDate()).toBe(14);
    expect(r.visitDate?.getMonth()).toBe(2);
  });
  it('reads French and Spanish labels', () => {
    const fr = parseReport('Clinique Vétérinaire du Lac\nDate : 3 mars 2026\nMotif : vomissements\nDiagnostic : gastrite\nMontant total : 89,90 €', 'FR');
    expect(fr.reason).toBe('vomissements');
    expect(fr.diagnosis).toBe('gastrite');
    expect(fr.totalCost).toBe(89.9);
    expect(fr.visitDate?.getMonth()).toBe(2);
    const es = parseReport('Clínica Veterinaria Sol\nMotivo de consulta: cojera\nDiagnóstico: esguince\nTratamiento: reposo\nTotal: 60,00 €', 'ES');
    expect(es.reason).toBe('cojera');
    expect(es.treatment).toBe('reposo');
  });
  it('converts pounds and normalizes numbers', () => {
    expect(weightIn('Weight 62.5 lbs')).toBe(28.35);
    expect(normalizeNumber('1,234.56')).toBe(1234.56);
    expect(normalizeNumber('1.234,56')).toBe(1234.56);
    expect(normalizeNumber('1.200')).toBe(1200);
    expect(amountIn('Total 1 234,50 EUR')).toBe(1234.5);
    expect(firstDate('March 3, 2026', true)?.getDate()).toBe(3);
  });
});

describe('travel planner', () => {
  const arrival = addDays(new Date(), 60);
  it('lists EU steps with tapeworm for dogs to Ireland', () => {
    const steps = travelSteps(destination('IE'), arrival, { species: 'dog', microchip: '985112004556781' });
    expect(steps.map((s) => s.id)).toEqual(['microchip', 'rabies', 'tapeworm', 'certificate', 'endorsement', 'airline']);
    expect(steps[0].autoSatisfied).toBe(true);
    const cert = steps.find((s) => s.id === 'certificate')!;
    expect(daysBetween(cert.windowStart!, arrival)).toBe(10);
    expect(stepState(cert, false)).toBe('upcoming');
  });
  it('no tapeworm for cats or Germany', () => {
    expect(travelSteps(destination('IE'), arrival, { species: 'cat', microchip: '' }).some((s) => s.id === 'tapeworm')).toBe(false);
    expect(travelSteps(destination('DE'), arrival, { species: 'dog', microchip: '' }).some((s) => s.id === 'tapeworm')).toBe(false);
  });
  it('uses CDC rules for dogs to the US', () => {
    const young = travelSteps(destination('US'), arrival, { species: 'dog', microchip: '', birthDate: addDays(new Date(), -100) });
    expect(young.find((s) => s.id === 'age')!.autoSatisfied).toBe(false);
    expect(young.some((s) => s.id === 'cdcForm')).toBe(true);
  });
  it('accepts a rabies vaccine given early enough', () => {
    const steps = travelSteps(destination('FR'), arrival, {
      species: 'cat', microchip: '', rabiesGiven: addDays(new Date(), -200), rabiesValidUntil: addDays(new Date(), 200),
    });
    expect(steps.find((s) => s.id === 'rabies')!.autoSatisfied).toBe(true);
  });
});

describe('food safety', () => {
  it('finds items in any language', () => {
    expect(searchFoods('schokolade')[0].id).toBe('chocolate');
    expect(searchFoods('uvas')[0].id).toBe('grapes');
    expect(searchFoods('oignon')[0].id).toBe('onion');
  });
  it('lilies are an emergency for cats only', () => {
    const lily = FOOD_ITEMS.find((i) => i.id === 'lily')!;
    expect(levelFor(lily, 'cat')).toBe('emergency');
    expect(levelFor(lily, 'dog')).toBe('caution');
  });
});

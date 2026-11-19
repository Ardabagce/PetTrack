import { blankPet } from './actions';
import { addDays, addMonths, atTime } from './dates';
import { defaultCurrency } from './format';
import { getState, newId } from './store';
import type { Collections } from './types';

/** Realistic demo data so the app can be explored right away (also used by the web preview). */
export function loadDemoData() {
  const now = new Date();
  const cur = defaultCurrency();
  const luna = { ...blankPet('Luna', 'dog', 0), breed: 'Golden Retriever', birthDate: addMonths(now, -40).toISOString(), sex: 'female' as const,
    neutered: true, microchip: '985 112 004 556 781', allergies: 'Chicken protein', vetClinic: 'Riverside Animal Clinic', vetName: 'Dr. Emma Hart',
    vetPhone: '+1 555 0142', vetEmail: 'care@riverside.vet', insuranceProvider: 'Lemonade Pet', insurancePolicy: 'LP-2291-884', targetWeightKg: 28, activity: 'normal' as const, foodKcal100g: 365 };
  const milo = { ...blankPet('Milo', 'cat', 2), breed: 'British Shorthair', birthDate: addMonths(now, -19).toISOString(), sex: 'male' as const, neutered: true, microchip: '276 098 106 223 511' };
  const caseId = newId();
  const visitId = newId();
  const d = (n: number, h = 9) => atTime(addDays(now, n), h, 0).toISOString();
  const data: Collections = {
    pets: [luna, milo],
    weights: [[-150, 27.1], [-120, 27.6], [-90, 28.0], [-60, 28.4], [-30, 28.2], [-5, 28.9]].map(([o, kg]) => ({ id: newId(), petId: luna.id, date: d(o), kg, note: '' }))
      .concat([[-90, 4.6], [-30, 4.9], [-3, 5.1]].map(([o, kg]) => ({ id: newId(), petId: milo.id, date: d(o), kg, note: '' }))),
    vaccinations: [
      { id: newId(), petId: luna.id, name: 'Rabies', dateGiven: addMonths(now, -11).toISOString(), nextDue: addDays(now, 20).toISOString(), batch: 'RB-4471', by: 'Dr. Emma Hart', notes: '' },
      { id: newId(), petId: luna.id, name: 'DHPP', dateGiven: addMonths(now, -4).toISOString(), nextDue: addMonths(now, 8).toISOString(), batch: '', by: '', notes: '' },
      { id: newId(), petId: luna.id, name: 'Leptospirosis', dateGiven: addMonths(now, -13).toISOString(), nextDue: addDays(now, -6).toISOString(), batch: '', by: '', notes: '' },
      { id: newId(), petId: milo.id, name: 'FVRCP', dateGiven: addMonths(now, -6).toISOString(), nextDue: addMonths(now, 6).toISOString(), batch: '', by: '', notes: '' },
    ],
    visits: [{ id: visitId, petId: luna.id, date: d(-12), clinic: 'Riverside Animal Clinic', vet: 'Dr. Emma Hart', reason: 'Itchy belly', diagnosis: 'Contact dermatitis',
      treatment: 'Medicated shampoo twice a week, recheck in 2 weeks', notes: '', cost: 145, currency: cur, followUp: d(2), source: 'manual' }],
    expenses: [
      { id: newId(), petId: luna.id, date: d(-12), title: 'Dermatology visit', amount: 145, currency: cur, category: 'vet', note: '' },
      { id: newId(), petId: luna.id, date: d(-40), title: 'Salmon & Rice 12 kg', amount: 68, currency: cur, category: 'food', note: '' },
      { id: newId(), petId: luna.id, date: d(-70), title: 'Insurance', amount: 32, currency: cur, category: 'insurance', note: '' },
      { id: newId(), petId: luna.id, date: d(-100), title: 'Grooming', amount: 55, currency: cur, category: 'grooming', note: '' },
    ],
    medications: [{ id: newId(), petId: luna.id, name: 'Medicated shampoo', dosage: '2× week', instructions: 'Leave on 10 minutes', start: d(-12) }],
    slots: [
      { id: newId(), petId: luna.id, label: 'Breakfast', kind: 'meal', hour: 8, minute: 0, food: 'Salmon & Rice', portion: 180, enabled: true, notify: true },
      { id: newId(), petId: luna.id, label: 'Fresh water', kind: 'water', hour: 9, minute: 0, food: '', portion: 500, enabled: true, notify: true },
      { id: newId(), petId: luna.id, label: 'Dinner', kind: 'meal', hour: 18, minute: 0, food: 'Salmon & Rice', portion: 180, enabled: true, notify: true },
      { id: newId(), petId: milo.id, label: 'Breakfast', kind: 'meal', hour: 7, minute: 30, food: 'Wet food', portion: 85, enabled: true, notify: true },
      { id: newId(), petId: milo.id, label: 'Dinner', kind: 'meal', hour: 19, minute: 0, food: 'Wet food', portion: 85, enabled: true, notify: true },
    ],
    logs: Array.from({ length: 12 }, (_, i) => ({ id: newId(), petId: luna.id, date: atTime(addDays(now, -1 - Math.floor(i / 2)), i % 2 ? 18 : 8, 5).toISOString(),
      kind: 'meal' as const, amount: 180, source: 'manual' as const, fedBy: i % 3 === 0 ? 'Sam' : 'Alex' })),
    transitions: [],
    reminders: [
      { id: newId(), petId: luna.id, title: 'Flea & tick tablet', notes: '', due: d(4, 19), repeat: 'monthly', category: 'parasite', done: false },
      { id: newId(), petId: milo.id, title: 'Brush teeth', notes: '', due: d(1, 20), repeat: 'weekly', category: 'grooming', done: false },
    ],
    symptomCases: [{ id: caseId, petId: luna.id, title: 'Red patch on belly', area: 'Belly', start: d(-14), resolved: false, notes: 'Started after a walk in tall grass.', dailyReminder: true }],
    symptomEntries: [
      { id: newId(), caseId, date: d(-14, 8), severity: 4, note: 'Red, warm, she keeps licking it.', photo: swatch('#C9654B', '#8E3B2E') },
      { id: newId(), caseId, date: d(-10, 19), severity: 3, note: 'Less warm, still itchy.', photo: swatch('#CF7A5E', '#A0503F') },
      { id: newId(), caseId, date: d(-5, 19), severity: 2, note: 'Smaller after the shampoo.', photo: swatch('#D9987E', '#B87563') },
      { id: newId(), caseId, date: d(-1, 19), severity: 1, note: 'Almost gone.', photo: swatch('#E2B8A4', '#C99A86') },
    ],
    travelPlans: [{ id: newId(), petId: luna.id, destination: 'DE', departure: d(44), arrival: d(45), done: ['airline'], notes: 'LH 431 · Berlin' }],
    claims: [{ id: newId(), petId: luna.id, visitId, insurer: 'Lemonade Pet', policy: 'LP-2291-884', claimNo: '', status: 'submitted', claimed: 145, currency: cur,
      submittedAt: d(-10), includeSymptoms: true, notes: '', createdAt: d(-10) }],
    checkins: [
      [6, 4, 4, 'normal', false], [5, 5, 5, 'normal', false], [4, 4, 4, 'soft', false], [3, 4, 3, 'normal', false],
      [2, 3, 2, 'soft', true], [1, 3, 2, 'normal', false],
    ].map(([o, energy, appetite, stool, vomit]) => ({ id: newId(), petId: luna.id, date: d(-(o as number), 20), energy: energy as number, appetite: appetite as number,
      stool: stool as 'normal' | 'soft', vomit: vomit as boolean, note: '' })),
    bcs: [{ id: newId(), petId: luna.id, date: d(-30), score: 6 }],
    questions: [
      { id: newId(), petId: luna.id, text: 'Should we switch to a hypoallergenic food?', createdAt: d(-3), answered: false },
      { id: newId(), petId: luna.id, text: 'Is the Leptospirosis booster overdue a problem?', createdAt: d(-1), answered: false },
    ],
  };
  getState().replaceAll(data);
  getState().setSettings({ selectedPetId: luna.id, memberName: getState().settings.memberName || 'Alex' });
}

/** Tiny SVG "photo" placeholder so the demo symptom diary has images without bundling assets. */
function swatch(a: string, b: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300"><defs><radialGradient id="g" cx="50%" cy="50%" r="60%"><stop offset="0" stop-color="${b}"/><stop offset="0.45" stop-color="${a}"/><stop offset="1" stop-color="#E9D3C2"/></radialGradient></defs><rect width="400" height="300" fill="url(#g)"/></svg>`;
  return `data:image/svg+xml;base64,${btoa(svg)}`;
}

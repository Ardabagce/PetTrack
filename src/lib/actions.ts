import { Platform } from 'react-native';
import * as Haptics from 'expo-haptics';
import { api, hasBackend } from './api';
import { addDays, addMonths, addYears } from './dates';
import { formatTime } from './format';
import { tr } from './i18n';
import * as notify from './notifications';
import { getState, newId } from './store';
import type { FeedingKind, FeedingLog, LogSource, Pet, Reminder } from './types';

export function haptic(kind: 'light' | 'success' | 'select' = 'light') {
  if (Platform.OS === 'web') return;
  if (kind === 'success') Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
  else if (kind === 'select') Haptics.selectionAsync().catch(() => {});
  else Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
}

/** Single entry point for logging a feeding: attributes it to the family member and shares it. */
export function logFeeding(pet: Pet, kind: FeedingKind, opts: { amount?: number; slotId?: string; source?: LogSource; fedBy?: string; date?: Date } = {}): FeedingLog {
  const { settings, upsert } = getState();
  const log: FeedingLog = {
    id: newId(),
    petId: pet.id,
    date: (opts.date ?? new Date()).toISOString(),
    kind,
    amount: opts.amount ?? 0,
    source: opts.source ?? 'manual',
    fedBy: opts.fedBy ?? settings.memberName,
    slotId: opts.slotId,
  };
  upsert('logs', log);
  haptic('success');
  if (settings.household.role !== 'none' && hasBackend() && log.source !== 'household') {
    api('/api/household/events', { method: 'POST', body: { events: [toEvent(log)] } }).catch(() => {});
  }
  return log;
}

export const toEvent = (l: FeedingLog) => ({ id: l.id, petId: l.petId, kind: l.kind, date: l.date, amount: l.amount, fedBy: l.fedBy, slotId: l.slotId });

/** Pulls feeding events from family members and pushes local ones. */
export async function syncHousehold(): Promise<number> {
  const { settings, data, upsertMany, setSettings } = getState();
  if (settings.household.role === 'none' || !hasBackend()) return 0;
  const pets = data.pets.map((p) => ({ id: p.id, name: p.name, species: p.species }));
  const slots = data.slots.map((s) => ({ ...s }));
  const since = settings.household.lastSync ?? addDays(new Date(), -7).toISOString();
  const local = data.logs.filter((l) => l.source !== 'household' && l.date >= since).map(toEvent);
  const res = await api<{ events: (ReturnType<typeof toEvent> & { fedBy: string })[]; pets: { id: string; name: string; species: Pet['species'] }[]; members: string[] }>(
    '/api/household/sync', { method: 'POST', body: { since, events: local, pets, slots } },
  );
  const known = new Set(getState().data.logs.map((l) => l.id));
  const incoming: FeedingLog[] = res.events.filter((e) => !known.has(e.id)).map((e) => ({ ...e, source: 'household' as const }));
  // Members get a local copy of pets shared by the household owner.
  const localPets = new Set(getState().data.pets.map((p) => p.id));
  const newPets: Pet[] = res.pets.filter((p) => !localPets.has(p.id)).map((p, i) => ({
    ...blankPet(p.name, p.species, getState().data.pets.length + i), id: p.id,
  }));
  if (newPets.length) upsertMany('pets', newPets);
  if (incoming.length) upsertMany('logs', incoming);
  setSettings({ household: { ...getState().settings.household, members: res.members, lastSync: new Date().toISOString() } });
  return incoming.length;
}

export function blankPet(name: string, species: Pet['species'], colorIndex: number): Pet {
  return {
    id: newId(), name, species, breed: '', sex: 'unknown', neutered: false, colorIndex, microchip: '', bloodType: '', allergies: '',
    conditions: '', emergencyNotes: '', vetClinic: '', vetName: '', vetPhone: '', vetEmail: '', insuranceProvider: '',
    insurancePolicy: '', createdAt: new Date().toISOString(),
  };
}

/** Marks a reminder done; repeating ones roll forward to the next occurrence. */
export function completeReminder(r: Reminder, petName: string) {
  const { upsert } = getState();
  if (r.repeat === 'never') {
    upsert('reminders', { ...r, done: true });
    notify.cancelForItem(`reminder-${r.id}`);
    return;
  }
  let next = new Date(r.due);
  const step = (d: Date) => r.repeat === 'daily' ? addDays(d, 1) : r.repeat === 'weekly' ? addDays(d, 7) : r.repeat === 'monthly' ? addMonths(d, 1) : addYears(d, 1);
  do { next = step(next); } while (next <= new Date());
  const updated = { ...r, due: next.toISOString() };
  upsert('reminders', updated);
  notify.scheduleReminder(updated, petName);
}

export async function rescheduleAll(petId: string) {
  const { data } = getState();
  const pet = data.pets.find((p) => p.id === petId);
  if (!pet) return;
  for (const s of data.slots.filter((x) => x.petId === petId)) await notify.scheduleSlot(s, pet.name);
  for (const v of data.vaccinations.filter((x) => x.petId === petId)) await notify.scheduleVaccine(v, pet.name);
  for (const r of data.reminders.filter((x) => x.petId === petId)) await notify.scheduleReminder(r, pet.name);
}

export function conflictMessage(log: FeedingLog, petName: string): string {
  const time = formatTime(log.date);
  const kind = tr(log.kind === 'meal' ? 'Meal' : log.kind === 'water' ? 'Water' : 'Treat').toLowerCase();
  const me = getState().settings.memberName;
  return log.fedBy && log.fedBy !== me
    ? tr('{{a}} already logged a {{b}} for {{c}} at {{d}}.', { a: log.fedBy, b: kind, c: petName, d: time })
    : tr('A {{a}} was already logged for {{b}} at {{c}}.', { a: kind, b: petName, c: time });
}


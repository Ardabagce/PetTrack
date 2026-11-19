import { useMemo } from 'react';
import { isTransitionComplete } from './diet';
import { addDays, isSameDay, startOfDay } from './dates';
import { isPremiumActive, useStore } from './store';
import type { Collections, FeedingKind, FeedingLog, Pet, SymptomCase, Vaccination } from './types';

export type VaccineStatus = 'upToDate' | 'dueSoon' | 'overdue';

export function vaccineStatus(v: Vaccination, now = new Date()): VaccineStatus {
  if (!v.nextDue) return 'upToDate';
  const due = new Date(v.nextDue);
  if (due < startOfDay(now)) return 'overdue';
  if (due < addDays(now, 30)) return 'dueSoon';
  return 'upToDate';
}

const byPet = <T extends { petId: string }>(list: T[], petId?: string) => list.filter((x) => x.petId === petId);

/** Everything about one pet, sorted for display. */
export function petView(data: Collections, pet: Pet | undefined) {
  const id = pet?.id;
  const weights = byPet(data.weights, id).sort((a, b) => a.date.localeCompare(b.date));
  const vaccinations = byPet(data.vaccinations, id).sort((a, b) => (a.nextDue ?? '9999').localeCompare(b.nextDue ?? '9999'));
  const visits = byPet(data.visits, id).sort((a, b) => b.date.localeCompare(a.date));
  const symptomCases = byPet(data.symptomCases, id);
  const entriesFor = (c: SymptomCase) =>
    data.symptomEntries.filter((e) => e.caseId === c.id).sort((a, b) => a.date.localeCompare(b.date));
  const lastUpdated = (c: SymptomCase) => entriesFor(c).at(-1)?.date ?? c.start;
  return {
    pet,
    weights,
    latestWeight: weights.at(-1),
    vaccinations,
    visits,
    lastVisit: visits.find((v) => new Date(v.date) <= new Date()),
    expenses: byPet(data.expenses, id).sort((a, b) => b.date.localeCompare(a.date)),
    medications: byPet(data.medications, id),
    activeMedications: byPet(data.medications, id).filter((m) => !m.end || new Date(m.end) >= startOfDay(new Date())),
    slots: byPet(data.slots, id).sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute)),
    logs: byPet(data.logs, id).sort((a, b) => b.date.localeCompare(a.date)),
    activeTransition: byPet(data.transitions, id).find((t) => t.active && !isTransitionComplete(t)),
    reminders: byPet(data.reminders, id).filter((r) => !r.done).sort((a, b) => a.due.localeCompare(b.due)),
    symptomCases: symptomCases.sort((a, b) =>
      a.resolved !== b.resolved ? (a.resolved ? 1 : -1) : lastUpdated(b).localeCompare(lastUpdated(a))),
    openSymptomCases: symptomCases.filter((c) => !c.resolved),
    entriesFor,
    lastUpdated,
    travelPlans: byPet(data.travelPlans, id)
      .filter((t) => new Date(t.arrival) >= startOfDay(new Date()))
      .sort((a, b) => a.arrival.localeCompare(b.arrival)),
    claims: byPet(data.claims, id).sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
    questions: byPet(data.questions, id).filter((q) => !q.answered),
  };
}

export type PetView = ReturnType<typeof petView>;

export function useSelectedPet() {
  const data = useStore((s) => s.data);
  const selectedId = useStore((s) => s.settings.selectedPetId);
  return useMemo(() => {
    const pets = [...data.pets].sort((a, b) => a.createdAt.localeCompare(b.createdAt));
    const pet = pets.find((p) => p.id === selectedId) ?? pets[0];
    return { pets, ...petView(data, pet) };
  }, [data, selectedId]);
}

export function usePremium(): boolean {
  const settings = useStore((s) => s.settings);
  return isPremiumActive(settings);
}

export const logsToday = (logs: FeedingLog[], now = new Date()) => logs.filter((l) => isSameDay(l.date, now));

/** How close two logs of the same kind must be to count as possible double feeding. */
export function doubleFeedWindowMs(kind: FeedingKind): number | undefined {
  if (kind === 'meal') return 2 * 3600_000;
  if (kind === 'water') return 30 * 60_000;
  return undefined;
}

export function recentConflict(logs: FeedingLog[], kind: FeedingKind, now = new Date(), excludeSlot?: string): FeedingLog | undefined {
  const window = doubleFeedWindowMs(kind);
  if (!window) return undefined;
  return logs
    .filter((l) => l.kind === kind && Math.abs(now.getTime() - new Date(l.date).getTime()) < window)
    .filter((l) => !excludeSlot || l.slotId !== excludeSlot)
    .sort((a, b) => b.date.localeCompare(a.date))[0];
}

export function severityTrend(entries: { severity: number }[]): number | undefined {
  if (entries.length < 2) return undefined;
  return entries[entries.length - 1].severity - entries[0].severity;
}

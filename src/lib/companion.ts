import { requireOptionalNativeModule } from 'expo';
import { AppState, Platform } from 'react-native';
import { logFeeding } from './actions';
import { isSameDay } from './dates';
import { tr } from './i18n';
import { getState, useStore } from './store';
import type { Collections, FeedingKind, Settings } from './types';

/**
 * Keeps the home-screen widget and the Apple Watch app in sync with the app.
 * The native module only exists in App Store / TestFlight builds; in Expo Go and on web everything here is a no-op.
 */
interface CompanionModule {
  setSnapshot(json: string): void;
  takeWatchActions(): string;
  isWatchAppInstalled(): boolean;
  addListener(event: 'onWatchAction', cb: () => void): { remove(): void };
}

const native = Platform.OS === 'ios' ? requireOptionalNativeModule<CompanionModule>('PetTrackCompanion') : null;

export const companionAvailable = () => !!native;

export interface WatchAction { petId: string; slotId?: string; kind: FeedingKind; date: string }

/** Small, self-contained summary the Swift side renders – labels come pre-translated. */
export function buildSnapshot(data: Collections, settings: Settings, now = new Date()) {
  const pets = data.pets.map((pet) => {
    const logs = data.logs.filter((l) => l.petId === pet.id).sort((a, b) => b.date.localeCompare(a.date));
    const last = (kind: FeedingKind) => {
      const l = logs.find((x) => x.kind === kind);
      return l ? { date: l.date, by: l.fedBy || '' } : null;
    };
    const vaccine = data.vaccinations
      .filter((v) => v.petId === pet.id && v.nextDue)
      .sort((a, b) => a.nextDue!.localeCompare(b.nextDue!))[0];
    return {
      id: pet.id,
      name: pet.name,
      species: pet.species,
      slots: data.slots
        .filter((s) => s.petId === pet.id && s.enabled)
        .sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute))
        .map((s) => ({ id: s.id, label: s.label, kind: s.kind, hour: s.hour, minute: s.minute })),
      // Recent logs tied to a slot, so the widget can tick slots off for "today" on its own timeline.
      done: logs.filter((l) => l.slotId && Date.parse(l.date) > now.getTime() - 2 * 86_400_000)
        .map((l) => ({ slotId: l.slotId!, kind: l.kind, date: l.date })),
      lastMeal: last('meal'),
      lastWater: last('water'),
      vaccine: vaccine ? { name: vaccine.name, due: vaccine.nextDue! } : null,
    };
  });
  return {
    v: 1,
    updatedAt: now.toISOString(),
    selectedPetId: settings.selectedPetId ?? data.pets[0]?.id ?? null,
    labels: {
      next: tr('Next'),
      allDone: tr('All done for today'),
      noSlots: tr('No feeding times yet'),
      noPets: tr('Open PetTrack to add your pet'),
      lastMeal: tr('Last meal'),
      lastWater: tr('Last water'),
      never: tr('Not logged yet'),
      vaccine: tr('Vaccine due'),
      markDone: tr('Mark done'),
      done: tr('Done'),
      today: tr('Today'),
      meal: tr('Meal'),
      water: tr('Water'),
      treat: tr('Treat'),
    },
    pets,
  };
}

/** Applies feedings tapped on the Watch. Skips a slot that was already logged today (e.g. by a family member). */
export function applyWatchActions(actions: WatchAction[]) {
  let applied = 0;
  for (const a of actions) {
    const { data } = getState();
    const pet = data.pets.find((p) => p.id === a.petId);
    if (!pet) continue;
    const date = new Date(a.date);
    if (Number.isNaN(date.getTime())) continue;
    if (a.slotId && data.logs.some((l) => l.petId === pet.id && l.slotId === a.slotId && isSameDay(l.date, date))) continue;
    const slot = a.slotId ? data.slots.find((s) => s.id === a.slotId) : undefined;
    logFeeding(pet, a.kind, { slotId: a.slotId, source: 'watch', amount: slot?.portion, date });
    applied++;
  }
  return applied;
}

function drain() {
  if (!native) return;
  try {
    const actions = JSON.parse(native.takeWatchActions() || '[]') as WatchAction[];
    if (actions.length) applyWatchActions(actions);
  } catch { /* malformed payload – ignore */ }
}

let started = false;

/** Call once after the store is hydrated. */
export function startCompanionSync() {
  if (!native || started) return;
  started = true;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let lastJson = '';
  const push = () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      const { data, settings } = getState();
      const json = JSON.stringify(buildSnapshot(data, settings));
      // updatedAt changes every time – compare without it.
      const key = json.replace(/"updatedAt":"[^"]*",/, '');
      if (key === lastJson) return;
      lastJson = key;
      try { native.setSnapshot(json); } catch { /* widget/watch unavailable */ }
    }, 400);
  };
  useStore.subscribe((s, prev) => {
    if (s.data !== prev.data || s.settings.selectedPetId !== prev.settings.selectedPetId || s.settings.language !== prev.settings.language) push();
  });
  native.addListener('onWatchAction', drain);
  AppState.addEventListener('change', (state) => {
    if (state === 'active') { drain(); lastJson = ''; push(); }
  });
  drain();
  push();
}

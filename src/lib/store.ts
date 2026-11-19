import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import type { CollectionKey, Collections, ID, ItemOf, Settings } from './types';

export const newId = () =>
  `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`;

const emptyCollections = (): Collections => ({
  pets: [], vaccinations: [], weights: [], visits: [], expenses: [], medications: [], slots: [], logs: [],
  transitions: [], reminders: [], symptomCases: [], symptomEntries: [], travelPlans: [], claims: [], questions: [],
});

const defaultSettings: Settings = {
  weightUnit: 'auto',
  memberName: '',
  tourDone: false,
  tipsSeen: [],
  lastWhatsNew: '',
  premium: { active: false, trialUsed: false },
  household: { role: 'none', members: [] },
};

interface State {
  data: Collections;
  settings: Settings;
  hydrated: boolean;
  upsert: <K extends CollectionKey>(key: K, item: ItemOf<K>) => void;
  upsertMany: <K extends CollectionKey>(key: K, items: ItemOf<K>[]) => void;
  remove: (key: CollectionKey, id: ID) => void;
  setSettings: (patch: Partial<Settings>) => void;
  deletePet: (petId: ID) => void;
  replaceAll: (data: Collections) => void;
}

export const useStore = create<State>()(
  persist(
    (set) => ({
      data: emptyCollections(),
      settings: defaultSettings,
      hydrated: false,
      upsert: (key, item) =>
        set((s) => {
          const list = s.data[key] as ItemOf<typeof key>[];
          const index = list.findIndex((x) => x.id === item.id);
          const next = index >= 0 ? list.map((x, i) => (i === index ? item : x)) : [...list, item];
          return { data: { ...s.data, [key]: next } };
        }),
      upsertMany: (key, items) =>
        set((s) => {
          const map = new Map((s.data[key] as ItemOf<typeof key>[]).map((x) => [x.id, x]));
          for (const item of items) map.set(item.id, item);
          return { data: { ...s.data, [key]: [...map.values()] } };
        }),
      remove: (key, id) =>
        set((s) => ({ data: { ...s.data, [key]: (s.data[key] as { id: ID }[]).filter((x) => x.id !== id) } })),
      setSettings: (patch) => set((s) => ({ settings: { ...s.settings, ...patch } })),
      deletePet: (petId) =>
        set((s) => {
          const caseIds = new Set(s.data.symptomCases.filter((c) => c.petId === petId).map((c) => c.id));
          const data = { ...s.data };
          for (const key of Object.keys(data) as CollectionKey[]) {
            if (key === 'pets') data.pets = data.pets.filter((p) => p.id !== petId);
            else if (key === 'symptomEntries') data.symptomEntries = data.symptomEntries.filter((e) => !caseIds.has(e.caseId));
            else (data as Record<string, { petId?: ID }[]>)[key] = (data[key] as { petId?: ID }[]).filter((x) => x.petId !== petId);
          }
          return { data, settings: { ...s.settings, selectedPetId: data.pets[0]?.id } };
        }),
      replaceAll: (data) => set({ data: { ...emptyCollections(), ...data } }),
    }),
    {
      name: 'pettrack',
      version: 1,
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (s) => ({ data: s.data, settings: s.settings }),
      merge: (persisted, current) => {
        const p = (persisted ?? {}) as Partial<State>;
        return {
          ...current,
          data: { ...emptyCollections(), ...(p.data ?? {}) },
          settings: { ...defaultSettings, ...(p.settings ?? {}) },
        };
      },
      onRehydrateStorage: () => () => useStore.setState({ hydrated: true }),
    },
  ),
);

export const getState = () => useStore.getState();

/** Premium is active while subscribed or during the free trial. */
export function isPremiumActive(settings: Settings, now = new Date()): boolean {
  const p = settings.premium;
  if (!p.active) return false;
  if (p.trialEndsAt && !p.plan) return new Date(p.trialEndsAt) > now;
  return true;
}

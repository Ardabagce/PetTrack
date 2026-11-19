import { router } from 'expo-router';
import { create } from 'zustand';
import type { IconName } from '@/components/ui';
import { addDays } from './dates';
import { getState, isPremiumActive } from './store';

export const FREE_LIMITS = { pets: 1, openReminders: 3, slots: 3, symptomCases: 1 };

export type Feature =
  | 'unlimitedPets' | 'familySharing' | 'reportScanning' | 'symptomDiary' | 'travelPlanner' | 'claimPack'
  | 'passportExport' | 'dietTransition' | 'costInsights' | 'unlimitedReminders' | 'lostMode';

export const FEATURES: { id: Feature; title: string; subtitle: string; icon: IconName }[] = [
  { id: 'familySharing', title: 'Family sharing', subtitle: 'Everyone sees who fed the pet – no more double dinners.', icon: 'people' },
  { id: 'symptomDiary', title: 'Symptom photo diary', subtitle: 'Track a rash, lump or limp day by day and show your vet the whole story.', icon: 'camera' },
  { id: 'reportScanning', title: 'Scan vet reports', subtitle: 'Turn a photo of any vet report into a visit record.', icon: 'scan' },
  { id: 'passportExport', title: 'Shareable health passport', subtitle: 'Send a complete PDF passport to any vet in one tap.', icon: 'share-outline' },
  { id: 'travelPlanner', title: 'US ⇄ Europe travel planner', subtitle: 'Every vaccine, certificate and deadline for your trip, with countdown reminders.', icon: 'airplane' },
  { id: 'claimPack', title: 'Insurance claim pack', subtitle: 'Invoice, report and symptom diary in one PDF, ready for your insurer.', icon: 'document-attach' },
  { id: 'lostMode', title: 'Lost pet mode & poster', subtitle: 'Collar QR page turns into a lost-pet alert and a printable poster in one tap.', icon: 'qr-code' },
  { id: 'dietTransition', title: 'Food transition planner', subtitle: 'Day-by-day mixing plan with gentle reminders.', icon: 'swap-horizontal' },
  { id: 'costInsights', title: 'Cost insights', subtitle: 'See where your money goes, month by month.', icon: 'bar-chart' },
  { id: 'unlimitedPets', title: 'Unlimited pets', subtitle: "Keep every companion's records in one place.", icon: 'paw' },
  { id: 'unlimitedReminders', title: 'Unlimited reminders & feeding slots', subtitle: 'Medication, grooming, flea & tick – never miss one.', icon: 'notifications' },
];

/** Runs `action` for Premium users, otherwise opens the paywall highlighting `feature`. */
export function requirePremium(feature: Feature, action: () => void) {
  if (isPremiumActive(getState().settings)) action();
  else router.push({ pathname: '/paywall', params: { feature } });
}

export interface Plan { id: 'monthly' | 'yearly'; price: number; currency: string; display: string; perMonth?: string }

/**
 * Store adapter. Expo Go and the web preview use this simulated store; the App Store build swaps in
 * RevenueCat (react-native-purchases) with the same products: premium.monthly / premium.yearly, 3-day free trial.
 */
export const PLANS: Plan[] = [
  { id: 'yearly', price: 34.99, currency: 'USD', display: '$34.99', perMonth: '$2.92' },
  { id: 'monthly', price: 4.99, currency: 'USD', display: '$4.99' },
];

export const yearlySavings = () => 1 - PLANS[0].price / (PLANS[1].price * 12);

export const usePurchaseState = create<{ busy: boolean }>(() => ({ busy: false }));

export async function purchase(plan: Plan['id']): Promise<boolean> {
  const { settings, setSettings } = getState();
  usePurchaseState.setState({ busy: true });
  await new Promise((r) => setTimeout(r, 600));
  const trial = !settings.premium.trialUsed;
  setSettings({
    premium: {
      active: true,
      plan: trial ? undefined : plan,
      trialEndsAt: trial ? addDays(new Date(), 3).toISOString() : undefined,
      trialUsed: true,
    },
  });
  usePurchaseState.setState({ busy: false });
  return true;
}

export async function restorePurchases(): Promise<boolean> {
  return isPremiumActive(getState().settings);
}

export function setSimulatedPremium(active: boolean) {
  const { settings, setSettings } = getState();
  setSettings({ premium: { ...settings.premium, active, plan: active ? 'yearly' : undefined, trialEndsAt: undefined } });
}

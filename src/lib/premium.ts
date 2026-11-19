import Constants from 'expo-constants';
import { router } from 'expo-router';
import { Linking, Platform } from 'react-native';
import Purchases, { type CustomerInfo, INTRO_ELIGIBILITY_STATUS, type PurchasesPackage } from 'react-native-purchases';
import { create } from 'zustand';
import type { IconName } from '@/components/ui';
import { addDays } from './dates';
import { tr } from './i18n';
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

export interface Plan { id: 'monthly' | 'yearly'; price: number; currency: string; display: string; perMonth?: string; trial?: string }

/**
 * Purchases go through RevenueCat (StoreKit on iOS). Configure in App Store Connect + RevenueCat:
 * entitlement "premium", products pettrack_premium_monthly / pettrack_premium_yearly with a 3-day free trial,
 * packages $rc_monthly / $rc_annual in the current offering. See docs/STORE_SETUP.md.
 */
export const ENTITLEMENT = 'premium';
const RC_IOS_KEY: string =
  (process.env.EXPO_PUBLIC_REVENUECAT_IOS_KEY as string | undefined) ||
  ((Constants.expoConfig?.extra as { revenueCatIosKey?: string } | undefined)?.revenueCatIosKey ?? '');

const useRevenueCat = () => Platform.OS === 'ios' && RC_IOS_KEY.length > 0 && Constants.executionEnvironment !== 'storeClient';
/** Simulated store only for development and the web preview – never in an App Store build. */
const isExpoGo = () => Constants.executionEnvironment === 'storeClient';
const allowSimulation = () => !useRevenueCat() && (__DEV__ || Platform.OS === 'web' || isExpoGo());

const SIMULATED: Plan[] = [
  { id: 'yearly', price: 34.99, currency: 'USD', display: '$34.99', perMonth: '$2.92', trial: '3 days' },
  { id: 'monthly', price: 4.99, currency: 'USD', display: '$4.99', trial: '3 days' },
];

export const usePurchaseState = create<{ busy: boolean; plans: Plan[]; loading: boolean; error?: string }>(() => ({
  busy: false, plans: [], loading: true,
}));

let packages: Partial<Record<Plan['id'], PurchasesPackage>> = {};
let configured = false;

function applyCustomerInfo(info: CustomerInfo) {
  const ent = info.entitlements.active[ENTITLEMENT];
  const { settings, setSettings } = getState();
  setSettings({
    premium: {
      active: !!ent,
      plan: ent ? (ent.productIdentifier.includes('year') ? 'yearly' : 'monthly') : undefined,
      trialEndsAt: ent && ent.periodType === 'TRIAL' ? ent.expirationDate ?? undefined : undefined,
      trialUsed: settings.premium.trialUsed || !!ent,
    },
  });
}

/** Call once at app start. */
export async function initPurchases() {
  if (!useRevenueCat() || configured) return;
  try {
    Purchases.configure({ apiKey: RC_IOS_KEY });
    configured = true;
    Purchases.addCustomerInfoUpdateListener(applyCustomerInfo);
    applyCustomerInfo(await Purchases.getCustomerInfo());
  } catch {
    // Offline or not yet set up – the paywall shows that subscriptions are unavailable.
  }
}

const unitLabel = (n: number, unit: string) => {
  const u = unit.toLowerCase();
  const key = u.startsWith('day') ? '{{a}} days' : u.startsWith('week') ? '{{a}} weeks' : u.startsWith('month') ? '{{a}} months' : '{{a}} years';
  return tr(key, { a: n });
};

export async function loadPlans() {
  if (allowSimulation()) { usePurchaseState.setState({ plans: SIMULATED, loading: false }); return; }
  if (!useRevenueCat()) { usePurchaseState.setState({ plans: [], loading: false }); return; }
  usePurchaseState.setState({ loading: true, error: undefined });
  try {
    await initPurchases();
    const offering = (await Purchases.getOfferings()).current;
    const annual = offering?.annual ?? undefined;
    const monthly = offering?.monthly ?? undefined;
    packages = { yearly: annual, monthly };
    const ids = [annual, monthly].filter(Boolean).map((p) => p!.product.identifier);
    const eligibility = ids.length ? await Purchases.checkTrialOrIntroductoryPriceEligibility(ids).catch(() => ({} as Record<string, { status: number }>)) : {};
    const toPlan = (id: Plan['id'], pkg?: PurchasesPackage): Plan | undefined => {
      if (!pkg) return undefined;
      const p = pkg.product;
      const intro = p.introPrice;
      const eligible = (eligibility as Record<string, { status: number }>)[p.identifier]?.status !== INTRO_ELIGIBILITY_STATUS.INTRO_ELIGIBILITY_STATUS_INELIGIBLE;
      return {
        id, price: p.price, currency: p.currencyCode, display: p.priceString,
        perMonth: id === 'yearly' ? p.pricePerMonthString ?? undefined : undefined,
        trial: intro && intro.price === 0 && eligible ? unitLabel(intro.periodNumberOfUnits, intro.periodUnit) : undefined,
      };
    };
    usePurchaseState.setState({ plans: [toPlan('yearly', annual), toPlan('monthly', monthly)].filter(Boolean) as Plan[], loading: false });
  } catch (e) {
    usePurchaseState.setState({ plans: [], loading: false, error: (e as Error).message });
  }
}

export const yearlySavings = (plans: Plan[]) => {
  const y = plans.find((p) => p.id === 'yearly');
  const m = plans.find((p) => p.id === 'monthly');
  return y && m && m.price > 0 ? Math.max(0, 1 - y.price / (m.price * 12)) : 0;
};

export async function purchase(plan: Plan['id']): Promise<boolean> {
  usePurchaseState.setState({ busy: true });
  try {
    if (useRevenueCat()) {
      const pkg = packages[plan];
      if (!pkg) throw new Error(tr('Subscriptions are currently unavailable.'));
      const { customerInfo } = await Purchases.purchasePackage(pkg);
      applyCustomerInfo(customerInfo);
      return !!customerInfo.entitlements.active[ENTITLEMENT];
    }
    if (!allowSimulation()) throw new Error(tr('Subscriptions are currently unavailable.'));
    await new Promise((r) => setTimeout(r, 600));
    const { settings, setSettings } = getState();
    const trial = !settings.premium.trialUsed;
    setSettings({ premium: { active: true, plan: trial ? undefined : plan, trialEndsAt: trial ? addDays(new Date(), 3).toISOString() : undefined, trialUsed: true } });
    return true;
  } catch (e) {
    const err = e as { userCancelled?: boolean; message?: string };
    if (!err.userCancelled) usePurchaseState.setState({ error: err.message });
    return false;
  } finally {
    usePurchaseState.setState({ busy: false });
  }
}

export async function restorePurchases(): Promise<boolean> {
  if (useRevenueCat()) {
    try {
      const info = await Purchases.restorePurchases();
      applyCustomerInfo(info);
      return !!info.entitlements.active[ENTITLEMENT];
    } catch {
      return false;
    }
  }
  return isPremiumActive(getState().settings);
}

export async function manageSubscription() {
  if (useRevenueCat()) {
    try { await Purchases.showManageSubscriptions(); return; } catch { /* fall through */ }
  }
  Linking.openURL('https://apps.apple.com/account/subscriptions');
}

export function setSimulatedPremium(active: boolean) {
  if (!allowSimulation()) return;
  const { settings, setSettings } = getState();
  setSettings({ premium: { ...settings.premium, active, plan: active ? 'yearly' : undefined, trialEndsAt: undefined } });
}

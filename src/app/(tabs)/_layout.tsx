import Ionicons from '@expo/vector-icons/Ionicons';
import { Redirect, router, Tabs } from 'expo-router';
import { Platform, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { IconName } from '@/components/ui';
import { haptic } from '@/lib/actions';
import { useTranslation } from '@/lib/i18n';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';

const TABS: { name: string; title: string; icon: IconName; active: IconName }[] = [
  { name: 'index', title: 'Today', icon: 'sunny-outline', active: 'sunny' },
  { name: 'health', title: 'Health', icon: 'heart-outline', active: 'heart' },
  { name: 'nutrition', title: 'Nutrition', icon: 'restaurant-outline', active: 'restaurant' },
  { name: 'passport', title: 'Passport', icon: 'id-card-outline', active: 'id-card' },
];

interface BarProps {
  state: { index: number; routes: { key: string; name: string }[] };
  navigation: { navigate: (name: string) => void };
}

/** Floating capsule tab bar: icons only on screen, names for VoiceOver, + in the middle. */
function FloatingTabBar({ state }: BarProps) {
  const c = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  const item = (tab: (typeof TABS)[number]) => {
    const index = state.routes.findIndex((r) => r.name === tab.name);
    const focused = state.index === index;
    return (
      <Pressable key={tab.name} onPress={() => { haptic('select'); router.navigate(tab.name === 'index' ? '/' : (`/${tab.name}` as never)); }}
        accessibilityRole="tab" accessibilityLabel={t(tab.title)} accessibilityState={{ selected: focused }}
        style={{ flex: 1, alignItems: 'center', justifyContent: 'center', height: 48 }}>
        <View style={{ paddingHorizontal: 16, paddingVertical: 8, borderRadius: 999, backgroundColor: focused ? c.surfaceMuted : 'transparent' }}>
          <Ionicons name={focused ? tab.active : tab.icon} size={23} color={focused ? c.ink : c.ink3} />
        </View>
      </Pressable>
    );
  };
  return (
    <View pointerEvents="box-none" style={{ position: 'absolute', left: 0, right: 0, bottom: 0, paddingBottom: Math.max(insets.bottom, 12), paddingHorizontal: 18, alignItems: 'center' }}>
      <View style={{
        width: '100%', maxWidth: 460, flexDirection: 'row', alignItems: 'center', backgroundColor: c.scheme === 'dark' ? '#1c2420F2' : '#FFFDF9F2', borderRadius: 999, padding: 6,
        borderWidth: StyleSheet.hairlineWidth, borderColor: c.hairline,
        ...Platform.select({ web: { boxShadow: '0 12px 30px rgba(0,0,0,0.14)' }, default: { shadowColor: '#000', shadowOpacity: 0.14, shadowRadius: 22, shadowOffset: { width: 0, height: 10 }, elevation: 8 } }),
      }}>
        {TABS.slice(0, 2).map(item)}
        <Pressable onPress={() => { haptic(); router.push('/quick-add'); }} accessibilityRole="button" accessibilityLabel={t('Quick add')}
          style={({ pressed }) => ({ width: 52, height: 52, borderRadius: 26, backgroundColor: c.accent, alignItems: 'center', justifyContent: 'center', marginHorizontal: 4, transform: [{ scale: pressed ? 0.94 : 1 }] })}>
          <Ionicons name="add" size={30} color="#fff" />
        </Pressable>
        {TABS.slice(2).map(item)}
      </View>
    </View>
  );
}

export default function TabsLayout() {
  const hasPets = useStore((s) => s.data.pets.length > 0);
  const accepted = useStore((s) => s.settings.disclaimerAccepted);
  if (!accepted) return <Redirect href="/disclaimer" />;
  if (!hasPets) return <Redirect href="/onboarding" />;
  return (
    <Tabs screenOptions={{ headerShown: false }} tabBar={(props) => <FloatingTabBar {...(props as unknown as BarProps)} />}>
      {TABS.map((tab) => <Tabs.Screen key={tab.name} name={tab.name} options={{ title: tab.title }} />)}
    </Tabs>
  );
}

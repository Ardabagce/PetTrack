import { Inter_400Regular } from '@expo-google-fonts/inter/400Regular';
import { Inter_500Medium } from '@expo-google-fonts/inter/500Medium';
import { Inter_600SemiBold } from '@expo-google-fonts/inter/600SemiBold';
import { Inter_700Bold } from '@expo-google-fonts/inter/700Bold';
import { Newsreader_600SemiBold } from '@expo-google-fonts/newsreader/600SemiBold';
import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { ActivityIndicator, Appearance, AppState, Platform, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { HtmlPreview } from '@/components/extras';
import { T } from '@/components/ui';
import { syncHousehold } from '@/lib/actions';
import { startCompanionSync } from '@/lib/companion';
import { initPurchases } from '@/lib/premium';
import i18n from '@/lib/i18n';
import { useStore } from '@/lib/store';
import { fonts, useTheme } from '@/lib/theme';
import { useUI } from '@/lib/uiState';

const modal = { presentation: 'modal' as const, headerShown: true };

export default function RootLayout() {
  const c = useTheme();
  const hydrated = useStore((s) => s.hydrated);
  const language = useStore((s) => s.settings.language);
  const previewHtml = useUI((s) => s.previewHtml);
  const toastText = useUI((s) => s.toast);
  const [fontsLoaded] = useFonts({ Inter_400Regular, Inter_500Medium, Inter_600SemiBold, Inter_700Bold, Newsreader_600SemiBold });

  useEffect(() => {
    if (language && i18n.language !== language) i18n.changeLanguage(language);
  }, [language]);

  // Native pickers, alerts and the keyboard follow the in-app appearance choice too.
  const themePref = useStore((s) => s.settings.theme ?? 'system');
  useEffect(() => {
    if (Platform.OS === 'web') return;
    try { Appearance.setColorScheme((themePref === 'system' ? 'auto' : themePref) as never); } catch { /* older runtimes */ }
  }, [themePref]);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (s) => { if (s === 'active') syncHousehold().catch(() => {}); });
    syncHousehold().catch(() => {});
    initPurchases();
    return () => sub.remove();
  }, []);

  // Widget + Apple Watch summary (no-op outside native builds).
  useEffect(() => { if (hydrated) startCompanionSync(); }, [hydrated]);

  if (!hydrated || !fontsLoaded) {
    return <View style={{ flex: 1, backgroundColor: c.canvas, alignItems: 'center', justifyContent: 'center' }}><ActivityIndicator color={c.accent} /></View>;
  }

  return (
    <SafeAreaProvider>
      <StatusBar style={c.scheme === 'dark' ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerShown: false,
          headerStyle: { backgroundColor: c.canvas },
          headerShadowVisible: false,
          headerTintColor: c.ink,
          headerTitleStyle: { fontFamily: fonts.semibold, fontSize: 17 },
          contentStyle: { backgroundColor: c.canvas },
          headerBackButtonDisplayMode: 'minimal',
        }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="onboarding" options={{ animation: 'fade' }} />
        <Stack.Screen name="tour" options={{ presentation: 'fullScreenModal' }} />
        <Stack.Screen name="paywall" options={{ presentation: 'modal' }} />
        <Stack.Screen name="sos" options={{ presentation: 'fullScreenModal' }} />
        {/* Gate on first launch (no swipe-away); opened from Settings it is a normal sheet over the Settings modal. */}
        <Stack.Screen name="disclaimer" options={({ route }) => ((route.params as { view?: string } | undefined)?.view
          ? { presentation: 'modal' }
          : { animation: 'fade', gestureEnabled: false })} />
        <Stack.Screen name="family" options={modal} />
        <Stack.Screen name="quick-add" options={{ presentation: 'formSheet', sheetAllowedDetents: [0.62, 0.9], sheetCornerRadius: 30, sheetGrabberVisible: true }} />
        {['pet-edit', 'vaccine', 'weight', 'visit-edit', 'expense', 'reminder', 'slot', 'transition', 'claim', 'symptom-edit', 'symptom-entry', 'travel-edit', 'scan', 'settings', 'visit-prep', 'checkin', 'portions'].map((name) => (
          <Stack.Screen key={name} name={name} options={modal} />
        ))}
        {['visit/[id]', 'symptom/[id]', 'travel/[id]', 'food-safety', 'lost', 'converter'].map((name) => (
          <Stack.Screen key={name} name={name} options={{ headerShown: true, title: '' }} />
        ))}
      </Stack>
      <HtmlPreview html={previewHtml} onClose={() => useUI.setState({ previewHtml: null })} />
      {toastText && (
        <View pointerEvents="none" style={{ position: 'absolute', top: 60, left: 20, right: 20, alignItems: 'center' }} accessibilityLiveRegion="polite">
          <View style={{ backgroundColor: c.ink, borderRadius: 999, paddingHorizontal: 18, paddingVertical: 10 }}>
            <T color={c.canvas} style={{ fontFamily: fonts.semibold }}>{toastText}</T>
          </View>
        </View>
      )}
    </SafeAreaProvider>
  );
}

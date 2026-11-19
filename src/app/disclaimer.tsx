import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { Linking, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, Row, T } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { LINKS } from './paywall';

export const DISCLAIMER_VERSION = '1';

export const DISCLAIMER_POINTS = [
  'PetTrack is an organiser for your own notes and reminders. It is not a veterinary service and does not diagnose, treat or prevent any condition.',
  'Calculations, scores, food lists, travel checklists and alerts are general information from public sources. They can be incomplete, out of date or not right for your pet.',
  'Always ask a qualified veterinarian before making decisions about your pet’s health, food, medication or travel. In an emergency, contact a vet immediately.',
  'You are responsible for the information you enter and for checking anything the app fills in for you, such as scanned reports.',
  'To the extent permitted by law, PetTrack accepts no liability for decisions or actions based on the app.',
  'There is zero tolerance for offensive or abusive content on public pages and messages. By continuing you agree to the Terms of Use.',
];

/** Shown once before first use (and any time from Settings). */
export default function Disclaimer() {
  const c = useTheme();
  const { t } = useTranslation();
  const { view } = useLocalSearchParams<{ view?: string }>();
  const setSettings = useStore((s) => s.setSettings);
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.canvas }}>
      <ScrollView keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets keyboardDismissMode="interactive" contentContainerStyle={{ padding: 24, gap: 18 }}>
        <View style={{ width: 56, height: 56, borderRadius: 18, backgroundColor: `${c.sky}22`, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name="shield-checkmark" size={28} color={c.sky} />
        </View>
        <T variant="display" style={{ fontSize: 30 }}>{t('Before you start')}</T>
        <T variant="sub">{t('Please read this short notice. You can find it again in Settings.')}</T>
        {DISCLAIMER_POINTS.map((p) => (
          <Row key={p} gap={12} align="flex-start">
            <Ionicons name="checkmark-circle" size={20} color={c.sage} style={{ marginTop: 1 }} />
            <T style={{ flex: 1 }}>{t(p)}</T>
          </Row>
        ))}
        <Button variant="ghost" small title={t('Terms of use')} onPress={() => Linking.openURL(LINKS.terms)} />
        <Button variant="ghost" small title={t('Privacy policy')} onPress={() => Linking.openURL(LINKS.privacy)} />
        {view ? (
          <Button title={t('Close')} onPress={() => router.back()} />
        ) : (
          <Button title={t('I understand and agree')} onPress={() => { setSettings({ disclaimerAccepted: DISCLAIMER_VERSION }); router.replace('/'); }} />
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

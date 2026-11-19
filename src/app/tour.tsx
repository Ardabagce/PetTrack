import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, Row, T } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';

/** Where everything lives. Shown once after the first pet; replay from Settings. */
export const TOUR = [
  { icon: 'sunny', key: 'tint', eyebrow: 'Today', title: 'Your daily overview', message: "Meals and water to tick off, what's coming up and how your pet's weight is trending – all on one screen." },
  { icon: 'heart', key: 'accent', eyebrow: 'Health', title: 'The complete medical history', message: 'Vaccines with booster reminders, a vet journal, a symptom photo diary, weight charts and every bill.' },
  { icon: 'restaurant', key: 'sage', eyebrow: 'Nutrition', title: 'Feeding, made routine', message: 'Daily meal and water times, gentle food transitions and a quick check of which foods are safe.' },
  { icon: 'id-card', key: 'sky', eyebrow: 'Passport', title: 'Ready when it matters', message: 'Microchip, allergies, vet contacts and a shareable PDF passport for emergencies or a new vet.' },
  { icon: 'people', key: 'plum', eyebrow: 'Family', title: 'Who fed the dog?', message: 'Invite your family. Everyone sees who fed the pet and when – and PetTrack asks before anyone feeds twice.' },
  { icon: 'add', key: 'accent', eyebrow: 'Quick add', title: 'One button for everything', message: 'The + in the middle of the tab bar logs anything in a couple of taps.' },
] as const;

export const WHATS_NEW_VERSION = '1.0.0';

export default function Tour() {
  const c = useTheme();
  const { t } = useTranslation();
  const [page, setPage] = useState(0);
  const setSettings = useStore((s) => s.setSettings);
  const item = TOUR[page];
  const tint = { tint: c.butter, accent: c.accent, sage: c.sage, sky: c.sky, plum: c.plum }[item.key];
  const finish = () => { setSettings({ tourDone: true, lastWhatsNew: WHATS_NEW_VERSION }); router.back(); };
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.canvas, padding: 24 }}>
      <Row style={{ justifyContent: 'flex-end' }}>
        <Pressable onPress={finish} hitSlop={10} accessibilityRole="button"><T variant="headline" color={c.ink2}>{t('Skip')}</T></Pressable>
      </Row>
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', gap: 26 }} accessibilityLiveRegion="polite">
        <View style={{ width: 220, height: 220, borderRadius: 110, backgroundColor: `${tint}1F`, alignItems: 'center', justifyContent: 'center' }}>
          <View style={{ width: 150, height: 150, borderRadius: 75, backgroundColor: `${tint}2E`, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name={item.icon} size={64} color={tint} />
          </View>
        </View>
        <View style={{ gap: 10, alignItems: 'center', maxWidth: 420 }}>
          <T variant="eyebrow" color={tint}>{t(item.eyebrow)}</T>
          <T variant="display" center style={{ fontSize: 30 }}>{t(item.title)}</T>
          <T variant="sub" center style={{ fontSize: 16, lineHeight: 23 }}>{t(item.message)}</T>
        </View>
      </View>
      <Row gap={6} style={{ justifyContent: 'center', marginBottom: 20 }}>
        {TOUR.map((_, i) => <View key={i} style={{ width: i === page ? 22 : 7, height: 7, borderRadius: 4, backgroundColor: i === page ? c.ink : c.hairline }} />)}
      </Row>
      <Button title={t(page < TOUR.length - 1 ? 'Next' : 'Get started')} onPress={() => (page < TOUR.length - 1 ? setPage(page + 1) : finish())} />
    </SafeAreaView>
  );
}

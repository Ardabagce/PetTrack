import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { Redirect, router } from 'expo-router';
import { ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, Row, T } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { loadDemoData } from '@/lib/sample';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';

export default function Onboarding() {
  const c = useTheme();
  const { t } = useTranslation();
  const hasPets = useStore((s) => s.data.pets.length > 0);
  const accepted = useStore((s) => s.settings.disclaimerAccepted);
  if (!accepted) return <Redirect href="/disclaimer" />;
  if (hasPets) return <Redirect href="/" />;
  const feature = (icon: keyof typeof Ionicons.glyphMap, text: string) => (
    <Row gap={12}>
      <View style={{ width: 32, height: 32, borderRadius: 16, backgroundColor: c.cream, alignItems: 'center', justifyContent: 'center' }}>
        <Ionicons name={icon} size={16} color={c.forestDeep} />
      </View>
      <T color={c.cream} style={{ flex: 1 }}>{t(text)}</T>
    </Row>
  );
  return (
    <LinearGradient colors={[c.forest, c.forestDeep]} style={{ flex: 1 }}>
      <View style={{ position: 'absolute', right: -80, top: -60, width: 320, height: 320, borderRadius: 160, backgroundColor: '#CF5F3B', opacity: 0.3 }} />
      <SafeAreaView style={{ flex: 1 }}>
        <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: 'flex-end', padding: 26, gap: 22 }}>
          <Row gap={-12}>
            {(['paw', 'heart', 'medkit'] as const).map((icon, i) => (
              <View key={icon} style={{ width: 62, height: 62, borderRadius: 31, borderWidth: 3, borderColor: c.forestDeep, alignItems: 'center', justifyContent: 'center', backgroundColor: ['#CF5F3B', '#5A8A6E', '#4C7FAB'][i] }}>
                <Ionicons name={icon} size={26} color={c.cream} />
              </View>
            ))}
          </Row>
          <T variant="eyebrow" color="#F6F0E499">PetTrack</T>
          <T variant="display" color={c.cream} style={{ fontSize: 38, lineHeight: 44 }}>{t("A health passport for the ones who can't keep their own.")}</T>
          <T color="#F6F0E4B8">{t('Vaccines, vet visits, weight, meals and bills – organised in one beautiful place and ready to share with your vet in one tap.')}</T>
          <View style={{ gap: 14 }}>
            {feature('medkit', 'Vaccine schedule with smart reminders')}
            {feature('people', 'Who fed the dog? The whole family stays in sync')}
            {feature('camera', 'Symptom photo diary for your vet')}
          </View>
          <Button variant="light" title={t('Add your first pet')} onPress={() => router.push('/pet-edit')} />
          <Button variant="ghost" tint={c.cream} title={t('Explore with demo data')} onPress={() => { loadDemoData(); router.replace('/'); }} />
        </ScrollView>
      </SafeAreaView>
    </LinearGradient>
  );
}

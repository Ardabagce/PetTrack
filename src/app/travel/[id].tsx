import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { Linking, Pressable, View } from 'react-native';
import { Button, Card, Pill, Row, Screen, T } from '@/components/ui';
import { daysBetween } from '@/lib/dates';
import { countryName, formatDate } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { scheduleTravel } from '@/lib/notifications';
import { getState, useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import { destination, officialSource, petFacts, stepState, travelSteps } from '@/lib/travel';

export default function TravelDetail() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id: string }>();
  const data = useStore((s) => s.data);
  const plan = data.travelPlans.find((p) => p.id === id);
  const pet = data.pets.find((p) => p.id === plan?.petId);
  if (!plan || !pet) return <Screen title=""><T>—</T></Screen>;
  const dest = destination(plan.destination);
  const steps = travelSteps(dest, new Date(plan.arrival), petFacts(pet, data.vaccinations));
  const days = Math.max(0, daysBetween(new Date(), plan.arrival));
  const colors = { done: c.sage, ready: c.accent, upcoming: c.ink3, overdue: c.danger };
  const timing = (s: (typeof steps)[number]) =>
    s.windowStart && s.deadline ? t('Between {{a}} and {{b}}', { a: formatDate(s.windowStart), b: formatDate(s.deadline) })
      : s.deadline ? t('By {{a}}', { a: formatDate(s.deadline) }) : '';
  const toggle = (stepId: string) => {
    const next = { ...plan, done: plan.done.includes(stepId) ? plan.done.filter((x) => x !== stepId) : [...plan.done, stepId] };
    getState().upsert('travelPlans', next);
    scheduleTravel(next, pet, getState().data);
  };
  return (
    <Screen title="" headerRight={<Button small variant="ghost" title={t('Edit')} onPress={() => router.push({ pathname: '/travel-edit', params: { id: plan.id } })} />}>
      <LinearGradient colors={[c.sky, c.forestDeep]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ borderRadius: radius.card, padding: 20, flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ flex: 1, gap: 4 }}>
          <T variant="eyebrow" color="#F6F0E499">{t('Trip')}</T>
          <T variant="display" color={c.cream} style={{ fontSize: 28 }}>{dest.flag} {countryName(dest.code)}</T>
          <T color="#F6F0E4B3">{formatDate(plan.arrival, 'long')} · {pet.name}</T>
        </View>
        <View style={{ alignItems: 'center' }} accessible accessibilityLabel={t('In {{a}} days', { a: days })}>
          <T variant="display" color={c.cream} style={{ fontSize: 44, lineHeight: 50 }}>{days}</T>
          <T variant="caption" color="#F6F0E499">{t('days')}</T>
        </View>
      </LinearGradient>
      {steps.map((s) => {
        const state = stepState(s, plan.done.includes(s.id));
        return (
          <Card key={s.id} padding={14}>
            <Row gap={12} align="flex-start">
              <Pressable onPress={() => !s.autoSatisfied && toggle(s.id)} accessibilityRole="checkbox" accessibilityState={{ checked: state === 'done', disabled: s.autoSatisfied }} accessibilityLabel={t(s.title)} hitSlop={8}>
                <Ionicons name={state === 'done' ? 'checkmark-circle' : 'ellipse-outline'} size={26} color={colors[state]} />
              </Pressable>
              <View style={{ flex: 1, gap: 4 }}>
                <Row gap={6} style={{ flexWrap: 'wrap' }}>
                  <Ionicons name={s.icon as keyof typeof Ionicons.glyphMap} size={15} color={colors[state]} />
                  <T variant="headline" style={{ fontSize: 15 }}>{t(s.title)}</T>
                  {s.recommended && <Pill text={t('Recommended')} tint={c.ink3} />}
                </Row>
                <T variant="sub">{t(s.detail)}</T>
                {state === 'done'
                  ? s.autoSatisfied && <T variant="caption" color={c.sage}>{t("Found in {{a}}'s records", { a: pet.name })}</T>
                  : !!timing(s) && <T variant="caption" color={colors[state]}>{timing(s)}</T>}
              </View>
            </Row>
          </Card>
        );
      })}
      <Card>
        <Row align="flex-start"><Ionicons name="information-circle-outline" size={18} color={c.ink2} /><T variant="sub" style={{ flex: 1 }}>{t('Rules change. Always confirm with the official source and your airline before you travel.')}</T></Row>
        <Button variant="soft" title={t('Open official rules')} onPress={() => Linking.openURL(officialSource(dest.code))} />
      </Card>
    </Screen>
  );
}

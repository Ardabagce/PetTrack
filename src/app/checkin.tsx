import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { Banner, EditorHeader, Field, FormSection, Row, Screen, T, ToggleRow } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import type { CheckIn, Stool } from '@/lib/types';
import { checkinAlerts, checkinToday } from '@/lib/wellness';

const FACES = ['sad-outline', 'sad-outline', 'remove-circle-outline', 'happy-outline', 'happy'] as const;
const STOOL: { id: Stool; label: string }[] = [
  { id: 'normal', label: 'Normal' }, { id: 'soft', label: 'Soft' }, { id: 'diarrhea', label: 'Diarrhea' }, { id: 'hard', label: 'Hard' }, { id: 'none', label: 'None' },
];

/** 10-second daily check-in. Patterns across days become alerts on Today. */
export default function CheckInScreen() {
  const c = useTheme();
  const { t } = useTranslation();
  const { pet } = useSelectedPet();
  const all = useStore((s) => s.data.checkins);
  const mine = all.filter((x) => x.petId === pet?.id);
  const existing = checkinToday(mine);
  const [ci, setCi] = useState<CheckIn>(existing ?? { id: newId(), petId: pet!.id, date: new Date().toISOString(), energy: 4, appetite: 4, stool: 'normal', vomit: false, note: '' });
  const set = <K extends keyof CheckIn>(k: K, v: CheckIn[K]) => setCi((x) => ({ ...x, [k]: v }));

  const save = () => {
    getState().upsert('checkins', ci);
    const alerts = checkinAlerts([...mine.filter((x) => x.id !== ci.id), ci]);
    if (alerts.length) router.replace('/');
    else router.back();
  };

  const scale = (label: string, key: 'energy' | 'appetite', tint: string) => (
    <FormSection title={t(label)}>
      <Row gap={8}>
        {[1, 2, 3, 4, 5].map((n) => {
          const on = ci[key] === n;
          return (
            <Pressable key={n} onPress={() => set(key, n)} accessibilityRole="radio" accessibilityState={{ checked: on }} accessibilityLabel={`${t(label)} ${n}/5`}
              style={{ flex: 1, height: 56, borderRadius: radius.small, alignItems: 'center', justifyContent: 'center', backgroundColor: on ? tint : c.surfaceMuted }}>
              <Ionicons name={FACES[n - 1]} size={24} color={on ? '#fff' : c.ink3} />
            </Pressable>
          );
        })}
      </Row>
      <Row style={{ justifyContent: 'space-between' }}><T variant="caption">{t('Low')}</T><T variant="caption">{t('Usual')}</T><T variant="caption">{t('High')}</T></Row>
    </FormSection>
  );

  return (
    <Screen modal>
      <EditorHeader title={t('Daily check-in')} onSave={save} />
      <T variant="sub">{t('How is {{a}} today? Ten seconds a day helps spot problems early.', { a: pet?.name ?? '' })}</T>
      {scale('Energy', 'energy', c.sage)}
      {scale('Appetite', 'appetite', c.butter)}
      <FormSection title={t('Stool')}>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
          {STOOL.map((s) => {
            const on = ci.stool === s.id;
            return (
              <Pressable key={s.id} onPress={() => set('stool', s.id)} accessibilityRole="radio" accessibilityState={{ checked: on }}
                style={{ paddingHorizontal: 14, paddingVertical: 10, borderRadius: 999, backgroundColor: on ? c.ink : c.surfaceMuted }}>
                <T color={on ? c.canvas : c.ink} style={{ fontSize: 14 }}>{t(s.label)}</T>
              </Pressable>
            );
          })}
        </View>
        <ToggleRow label={t('Vomited today')} value={ci.vomit} onChange={(v) => set('vomit', v)} />
      </FormSection>
      <Field label={t('Notes')} value={ci.note} onChange={(v) => set('note', v)} multiline />
      {existing && <Banner icon="information-circle-outline" tint={c.sky} text={t('You already checked in today – saving updates it.')} />}
    </Screen>
  );
}

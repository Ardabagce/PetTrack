import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { DateField, MixBar } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Row, Screen, T } from '@/components/ui';
import { transitionPhases } from '@/lib/diet';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, requestPermission, scheduleTransition } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { DietTransition } from '@/lib/types';

export default function TransitionEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet, slots } = useSelectedPet();
  const existing = useStore((s) => s.data.transitions.find((x) => x.id === id));
  const [tr, setTr] = useState<DietTransition>(existing ?? { id: newId(), petId: pet!.id, fromFood: slots.find((s) => s.food)?.food ?? '', toFood: '', start: new Date().toISOString(), days: 7, notes: '', active: true });
  const set = <K extends keyof DietTransition>(k: K, v: DietTransition[K]) => setTr((x) => ({ ...x, [k]: v }));
  const save = () => {
    const { data, upsert } = getState();
    for (const other of data.transitions.filter((x) => x.petId === tr.petId && x.active && x.id !== tr.id)) { upsert('transitions', { ...other, active: false }); cancelForItem(`transition-${other.id}`); }
    upsert('transitions', { ...tr, active: true });
    requestPermission().then(() => scheduleTransition(tr, pet?.name ?? ''));
    router.back();
  };
  return (
    <Screen modal>
      <EditorHeader title={t('Food transition')} onSave={save} canSave={!!tr.fromFood.trim() && !!tr.toFood.trim()} />
      <FormSection title={t('Foods')} footer={t('Vets usually recommend switching over 7–10 days. Take it slower for sensitive stomachs.')}>
        <Field label={t('Current food')} value={tr.fromFood} onChange={(v) => set('fromFood', v)} />
        <Field label={t('New food')} value={tr.toFood} onChange={(v) => set('toFood', v)} />
      </FormSection>
      <FormSection title={t('Plan')}>
        <DateField label={t('Start')} value={new Date(tr.start)} onChange={(d) => set('start', d.toISOString())} />
        <Chips>{[7, 10, 14].map((d) => <Chip key={d} label={t('{{a}} days', { a: d })} selected={tr.days === d} onPress={() => set('days', d)} />)}</Chips>
      </FormSection>
      <FormSection title={t('Daily mix')}>
        {transitionPhases(tr.days).map((p) => (
          <Row key={p.from} gap={12} align="flex-start">
            <T variant="headline" style={{ width: 78, fontSize: 14 }}>{p.from === p.to ? t('Day {{a}}', { a: p.from }) : t('Day {{a}}–{{b}}', { a: p.from, b: p.to })}</T>
            <View style={{ flex: 1 }}><MixBar ratio={p.ratio} newFood={tr.toFood || t('New')} oldFood={tr.fromFood || t('Current')} /></View>
          </Row>
        ))}
      </FormSection>
      {existing && <Button variant="soft" tint={c.danger} title={t('End transition')} onPress={() => { getState().upsert('transitions', { ...tr, active: false }); cancelForItem(`transition-${tr.id}`); router.back(); }} />}
    </Screen>
  );
}

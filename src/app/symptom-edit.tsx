import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen, ToggleRow } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, requestPermission, scheduleSymptom } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { SymptomCase } from '@/lib/types';

const AREAS = ['Skin', 'Ear', 'Eye', 'Mouth & teeth', 'Paw', 'Leg', 'Belly', 'Back', 'Tail', 'Other'];

export default function SymptomCaseEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet } = useSelectedPet();
  const existing = useStore((s) => s.data.symptomCases.find((x) => x.id === id));
  const [sc, setSc] = useState<SymptomCase>(existing ?? { id: newId(), petId: pet!.id, title: '', area: '', start: new Date().toISOString(), resolved: false, notes: '', dailyReminder: true });
  const set = <K extends keyof SymptomCase>(k: K, v: SymptomCase[K]) => setSc((x) => ({ ...x, [k]: v }));
  const save = () => {
    getState().upsert('symptomCases', { ...sc, title: sc.title.trim() });
    requestPermission().then(() => scheduleSymptom(sc, pet?.name ?? ''));
    if (existing) router.back();
    else router.replace({ pathname: '/symptom-entry', params: { caseId: sc.id } });
  };
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit diary' : 'New symptom diary')} onSave={save} canSave={!!sc.title.trim()} saveLabel={existing ? undefined : t('Next')} />
      <Field value={sc.title} onChange={(v) => set('title', v)} placeholder={t('What are you noticing? (e.g. Red spot on belly)')} multiline autoFocus={!existing} />
      <FormSection title={t('Where')}>
        <Chips>{AREAS.map((a) => <Chip key={a} label={t(a)} selected={sc.area === t(a)} onPress={() => set('area', t(a))} />)}</Chips>
      </FormSection>
      <FormSection>
        <DateField label={t('First noticed')} value={new Date(sc.start)} max={new Date()} onChange={(d) => set('start', d.toISOString())} />
        <ToggleRow label={t('Daily photo reminder')} value={sc.dailyReminder} onChange={(v) => set('dailyReminder', v)} />
        <Field label={t('Notes')} value={sc.notes} onChange={(v) => set('notes', v)} multiline />
      </FormSection>
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete diary')} onPress={() => {
        const { remove, data } = getState();
        data.symptomEntries.filter((e) => e.caseId === sc.id).forEach((e) => remove('symptomEntries', e.id));
        remove('symptomCases', sc.id); cancelForItem(`symptom-${sc.id}`); router.dismissAll();
      }} />}
    </Screen>
  );
}

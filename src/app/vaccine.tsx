import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Row, Screen, ToggleRow } from '@/components/ui';
import { addYears } from '@/lib/dates';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, scheduleVaccine } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { Species, Vaccination } from '@/lib/types';

const SUGGESTED: Record<Species, string[]> = {
  dog: ['Rabies', 'DHPP', 'Leptospirosis', 'Bordetella', 'Lyme', 'Canine Influenza'],
  cat: ['Rabies', 'FVRCP', 'FeLV'],
  rabbit: ['RHDV1/RHDV2', 'Myxomatosis'],
  bird: ['Polyomavirus'],
  other: ['Rabies'],
};

export default function VaccineEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet } = useSelectedPet();
  const existing = useStore((s) => s.data.vaccinations.find((v) => v.id === id));
  const [v, setV] = useState<Vaccination>(existing ?? { id: newId(), petId: pet!.id, name: '', dateGiven: new Date().toISOString(), nextDue: addYears(new Date(), 1).toISOString(), batch: '', by: '', notes: '' });
  const set = <K extends keyof Vaccination>(k: K, val: Vaccination[K]) => setV((x) => ({ ...x, [k]: val }));
  const owner = useStore((s) => s.data.pets.find((p) => p.id === v.petId));
  const save = () => { getState().upsert('vaccinations', { ...v, name: v.name.trim() }); scheduleVaccine(v, owner?.name ?? ''); router.back(); };
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit vaccine' : 'Add vaccine')} onSave={save} canSave={!!v.name.trim()} />
      <Field value={v.name} onChange={(x) => set('name', x)} placeholder={t('Vaccine name')} big />
      <Chips>{SUGGESTED[owner?.species ?? 'dog'].map((s) => <Chip key={s} label={s} selected={v.name === s} onPress={() => set('name', s)} />)}</Chips>
      <FormSection title={t('Dates')}>
        <DateField label={t('Date given')} value={new Date(v.dateGiven)} onChange={(d) => set('dateGiven', d.toISOString())} />
        <ToggleRow label={t('Booster due')} value={!!v.nextDue} onChange={(on) => set('nextDue', on ? addYears(v.dateGiven, 1).toISOString() : undefined)} />
        {v.nextDue && <DateField label={t('Next due')} value={new Date(v.nextDue)} onChange={(d) => set('nextDue', d.toISOString())} />}
        {v.nextDue && <Row gap={8}>{[1, 2, 3].map((y) => <Button key={y} small variant="soft" tint={c.sky} title={`+${y}`} onPress={() => set('nextDue', addYears(v.dateGiven, y).toISOString())} />)}</Row>}
      </FormSection>
      <FormSection title={t('Details')}>
        <Field label={t('Batch / lot number')} value={v.batch} onChange={(x) => set('batch', x)} />
        <Field label={t('Administered by')} value={v.by} onChange={(x) => set('by', x)} />
        <Field label={t('Notes')} value={v.notes} onChange={(x) => set('notes', x)} multiline />
      </FormSection>
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete vaccine')} onPress={() => { getState().remove('vaccinations', v.id); cancelForItem(`vaccine-${v.id}`); router.back(); }} />}
    </Screen>
  );
}

import { router } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { EditorHeader, Field, FormSection, Screen, T } from '@/components/ui';
import { formatDate, formatWeight, parseDecimal, resolvedUnit, toKg } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';

export default function WeightEditor() {
  const { t } = useTranslation();
  const { pet, latestWeight } = useSelectedPet();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const [value, setValue] = useState('');
  const [date, setDate] = useState(new Date());
  const [note, setNote] = useState('');
  const n = parseDecimal(value);
  const save = () => { getState().upsert('weights', { id: newId(), petId: pet!.id, date: date.toISOString(), kg: toKg(n!, unit), note }); router.back(); };
  return (
    <Screen modal>
      <EditorHeader title={t('Log weight')} onSave={save} canSave={!!n && n > 0} />
      <Field value={value} onChange={setValue} placeholder="0.0" keyboard="decimal-pad" suffix={unit} big autoFocus />
      {latestWeight && <T variant="caption" center>{t('Last: {{a}} · {{b}}', { a: formatWeight(latestWeight.kg, unit), b: formatDate(latestWeight.date) })}</T>}
      <FormSection>
        <DateField label={t('Date')} value={date} max={new Date()} onChange={setDate} mode="datetime" />
        <Field label={t('Note')} value={note} onChange={setNote} />
      </FormSection>
    </Screen>
  );
}

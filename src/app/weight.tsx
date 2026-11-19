import { router } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Chip, Chips, EditorHeader, Field, FormSection, Row, Screen, T } from '@/components/ui';
import { formatDate, formatWeight, parseDecimal, resolvedUnit, toKg, weightValue } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';

export default function WeightEditor() {
  const { t } = useTranslation();
  const { pet, latestWeight } = useSelectedPet();
  const preferred = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const [unit, setUnit] = useState<'kg' | 'lb'>(preferred);
  const [value, setValue] = useState('');
  const [date, setDate] = useState(new Date());
  const [note, setNote] = useState('');
  const n = parseDecimal(value);
  const save = () => { getState().upsert('weights', { id: newId(), petId: pet!.id, date: date.toISOString(), kg: toKg(n!, unit), note }); router.back(); };
  return (
    <Screen modal>
      <EditorHeader title={t('Log weight')} onSave={save} canSave={!!n && n > 0} />
      <Field value={value} onChange={setValue} placeholder="0.0" keyboard="decimal-pad" suffix={unit} big autoFocus />
      <Row style={{ justifyContent: 'space-between' }}>
        <Chips>{(['kg', 'lb'] as const).map((u) => <Chip key={u} label={u} selected={unit === u} onPress={() => {
          const n = parseDecimal(value);
          if (n !== undefined && u !== unit) setValue(String(Math.round(weightValue(toKg(n, unit), u) * 10) / 10));
          setUnit(u);
        }} />)}</Chips>
        {n !== undefined && <T variant="number" color="#8C958F">= {formatWeight(toKg(n, unit), unit === 'kg' ? 'lb' : 'kg')}</T>}
      </Row>
      {latestWeight && <T variant="caption" center>{t('Last: {{a}} · {{b}}', { a: formatWeight(latestWeight.kg, preferred), b: formatDate(latestWeight.date) })}</T>}
      <FormSection>
        <DateField label={t('Date')} value={date} max={new Date()} onChange={setDate} mode="datetime" />
        <Field label={t('Note')} value={note} onChange={setNote} />
      </FormSection>
    </Screen>
  );
}

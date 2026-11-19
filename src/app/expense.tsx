import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen } from '@/components/ui';
import { CURRENCIES, defaultCurrency, parseDecimal } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { cap } from '@/lib/pdf';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { Expense, ExpenseCategory } from '@/lib/types';
import { CATEGORY_ICON } from './(tabs)/health';

export default function ExpenseEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet, expenses } = useSelectedPet();
  const existing = useStore((s) => s.data.expenses.find((e) => e.id === id));
  const [e, setE] = useState<Expense>(existing ?? { id: newId(), petId: pet!.id, date: new Date().toISOString(), title: '', amount: 0, currency: expenses[0]?.currency ?? defaultCurrency(), category: 'vet', note: '' });
  const [amount, setAmount] = useState(existing ? String(existing.amount) : '');
  const set = <K extends keyof Expense>(k: K, v: Expense[K]) => setE((x) => ({ ...x, [k]: v }));
  const n = parseDecimal(amount);
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit expense' : 'Add expense')} canSave={n !== undefined} onSave={() => { getState().upsert('expenses', { ...e, amount: n! }); router.back(); }} />
      <Field value={amount} onChange={setAmount} placeholder="0" keyboard="decimal-pad" suffix={e.currency} big autoFocus={!existing} />
      <Chips>{CURRENCIES.slice(0, 6).map((cur) => <Chip key={cur} label={cur} selected={e.currency === cur} onPress={() => set('currency', cur)} />)}</Chips>
      <Field label={t('Description')} value={e.title} onChange={(v) => set('title', v)} />
      <FormSection title={t('Category')}>
        <Chips>{(Object.keys(CATEGORY_ICON) as ExpenseCategory[]).map((k) => <Chip key={k} icon={CATEGORY_ICON[k]} label={t(cap(k))} selected={e.category === k} onPress={() => set('category', k)} />)}</Chips>
      </FormSection>
      <FormSection>
        <DateField label={t('Date')} value={new Date(e.date)} onChange={(d) => set('date', d.toISOString())} />
        <Field label={t('Note')} value={e.note} onChange={(v) => set('note', v)} multiline />
      </FormSection>
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete expense')} onPress={() => { getState().remove('expenses', e.id); router.back(); }} />}
    </Screen>
  );
}

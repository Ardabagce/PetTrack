import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Image, Pressable } from 'react-native';
import { DateField } from '@/components/extras';
import { Banner, Button, Chip, Chips, EditorHeader, Field, FormSection, Row, Screen, T, ToggleRow } from '@/components/ui';
import { addMonths, addYears } from '@/lib/dates';
import { CURRENCIES, defaultCurrency, parseDecimal, resolvedUnit, toKg, weightValue } from '@/lib/format';
import { tr, useTranslation } from '@/lib/i18n';
import { scheduleVaccine } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { VetVisit } from '@/lib/types';
import { useUI } from '@/lib/uiState';

export default function VisitEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id, fromScan } = useLocalSearchParams<{ id?: string; fromScan?: string }>();
  const { pet } = useSelectedPet();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const existing = useStore((s) => s.data.visits.find((v) => v.id === id));
  const draft = fromScan ? useUI.getState().scanDraft : null;
  const r = draft?.report;
  const [v, setV] = useState<VetVisit>(existing ?? {
    id: newId(), petId: pet!.id, date: (r?.visitDate ?? new Date()).toISOString(), clinic: r?.clinic || pet!.vetClinic, vet: r?.vet || pet!.vetName,
    reason: r?.reason ?? '', diagnosis: r?.diagnosis ?? '', treatment: r?.treatment ?? '', notes: '', cost: r?.totalCost, currency: r?.currency ?? defaultCurrency(),
    followUp: r?.followUp?.toISOString(), source: r ? 'scan' : 'manual', rawText: r?.rawText, attachment: draft?.image,
  });
  const [cost, setCost] = useState(v.cost !== undefined ? String(v.cost) : '');
  const [weight, setWeight] = useState(r?.weightKg ? String(Math.round(weightValue(r.weightKg, unit) * 10) / 10) : '');
  const [addExpense, setAddExpense] = useState(!existing);
  const [vaccines, setVaccines] = useState<string[]>(r?.vaccines ?? []);
  const [showRaw, setShowRaw] = useState(false);
  const set = <K extends keyof VetVisit>(k: K, val: VetVisit[K]) => setV((x) => ({ ...x, [k]: val }));

  const save = () => {
    const { upsert } = getState();
    const amount = parseDecimal(cost);
    const visit = { ...v, cost: amount };
    upsert('visits', visit);
    if (!existing) {
      const kg = parseDecimal(weight);
      if (kg) upsert('weights', { id: newId(), petId: v.petId, date: v.date, kg: toKg(kg, unit), note: tr('From vet visit') });
      if (addExpense && amount) upsert('expenses', { id: newId(), petId: v.petId, date: v.date, title: v.reason || v.diagnosis || tr('Vet visit'), amount, currency: v.currency, category: 'vet', note: '' });
      for (const name of vaccines) {
        const vac = { id: newId(), petId: v.petId, name, dateGiven: v.date, nextDue: addYears(v.date, 1).toISOString(), batch: '', by: v.vet, notes: '' };
        upsert('vaccinations', vac);
        scheduleVaccine(vac, pet?.name ?? '');
      }
    }
    useUI.setState({ scanDraft: null });
    router.back();
  };

  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit visit' : 'New vet visit')} onSave={save} />
      {r && <Banner icon="sparkles" tint={c.plum} text={t('We filled in what we could read. Please check every field before saving.')} />}
      {v.attachment && <Image source={{ uri: v.attachment }} style={{ height: 150, borderRadius: 16 }} resizeMode="cover" />}
      <FormSection title={t('Visit')}>
        <DateField label={t('Date')} value={new Date(v.date)} onChange={(d) => set('date', d.toISOString())} />
        <Field label={t('Clinic')} value={v.clinic} onChange={(x) => set('clinic', x)} />
        <Field label={t('Veterinarian')} value={v.vet} onChange={(x) => set('vet', x)} />
        <Field label={t('Reason for visit')} value={v.reason} onChange={(x) => set('reason', x)} multiline />
      </FormSection>
      <FormSection title={t('Medical')}>
        <Field label={t('Diagnosis')} value={v.diagnosis} onChange={(x) => set('diagnosis', x)} multiline />
        <Field label={t('Treatment & prescriptions')} value={v.treatment} onChange={(x) => set('treatment', x)} multiline />
        <Field label={t('Notes')} value={v.notes} onChange={(x) => set('notes', x)} multiline />
        <ToggleRow label={t('Follow-up visit')} value={!!v.followUp} onChange={(on) => set('followUp', on ? addMonths(v.date, 1).toISOString() : undefined)} />
        {v.followUp && <DateField label={t('Follow-up date')} value={new Date(v.followUp)} onChange={(d) => set('followUp', d.toISOString())} />}
      </FormSection>
      <FormSection title={t('Measurements & cost')}>
        {!existing && <Field label={t('Weight')} value={weight} onChange={setWeight} keyboard="decimal-pad" suffix={unit} placeholder={t('Optional')} />}
        <Field label={t('Cost')} value={cost} onChange={setCost} keyboard="decimal-pad" suffix={v.currency} placeholder={t('Optional')} />
        <Chips>{CURRENCIES.slice(0, 6).map((cur) => <Chip key={cur} label={cur} selected={v.currency === cur} onPress={() => set('currency', cur)} />)}</Chips>
        {!existing && <ToggleRow label={t('Add cost to expenses')} value={addExpense} onChange={setAddExpense} />}
      </FormSection>
      {(r?.vaccines.length ?? 0) > 0 && (
        <FormSection title={t('Vaccines detected')} footer={t('Selected vaccines are added to the vaccine schedule with a booster due in one year.')}>
          {r!.vaccines.map((name) => (
            <ToggleRow key={name} label={name} value={vaccines.includes(name)} onChange={(on) => setVaccines((x) => (on ? [...x, name] : x.filter((y) => y !== name)))} />
          ))}
        </FormSection>
      )}
      {!!v.rawText && (
        <FormSection>
          <Pressable onPress={() => setShowRaw(!showRaw)} accessibilityRole="button"><Row style={{ justifyContent: 'space-between' }}><T variant="headline">{t('Recognized text')}</T><Ionicons name={showRaw ? 'chevron-up' : 'chevron-down'} size={16} color={c.ink2} /></Row></Pressable>
          {showRaw && <T variant="caption" style={{ fontFamily: 'monospace' }}>{v.rawText}</T>}
        </FormSection>
      )}
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete visit')} onPress={() => { getState().remove('visits', v.id); router.dismissAll(); }} />}
    </Screen>
  );
}

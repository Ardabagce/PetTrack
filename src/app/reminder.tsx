import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen } from '@/components/ui';
import { addDays } from '@/lib/dates';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, requestPermission, scheduleReminder } from '@/lib/notifications';
import { cap } from '@/lib/pdf';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { Reminder, ReminderCategory, RepeatRule } from '@/lib/types';

const CATS: { id: ReminderCategory; label: string; icon: keyof typeof Ionicons.glyphMap }[] = [
  { id: 'medication', label: 'Medication', icon: 'bandage' }, { id: 'parasite', label: 'Flea & tick', icon: 'bug' },
  { id: 'grooming', label: 'Grooming', icon: 'cut' }, { id: 'vet', label: 'Vet visit', icon: 'medical' },
  { id: 'vaccine', label: 'Vaccine', icon: 'medkit' }, { id: 'other', label: 'Other', icon: 'notifications' },
];

export default function ReminderEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet } = useSelectedPet();
  const existing = useStore((s) => s.data.reminders.find((r) => r.id === id));
  const [r, setR] = useState<Reminder>(existing ?? { id: newId(), petId: pet!.id, title: '', notes: '', due: addDays(new Date(), 1).toISOString(), repeat: 'never', category: 'medication', done: false });
  const set = <K extends keyof Reminder>(k: K, v: Reminder[K]) => setR((x) => ({ ...x, [k]: v }));
  const save = () => { const next = { ...r, title: r.title.trim(), done: false }; getState().upsert('reminders', next); requestPermission().then(() => scheduleReminder(next, pet?.name ?? '')); router.back(); };
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit reminder' : 'New reminder')} onSave={save} canSave={!!r.title.trim()} />
      <Field value={r.title} onChange={(v) => set('title', v)} placeholder={t('What should we remind you about?')} autoFocus={!existing} />
      <FormSection title={t('Type')}>
        <Chips>{CATS.map((x) => <Chip key={x.id} icon={x.icon} label={t(x.label)} selected={r.category === x.id} onPress={() => { set('category', x.id); if (!r.title || CATS.some((y) => t(y.label) === r.title)) set('title', t(x.label)); }} />)}</Chips>
      </FormSection>
      <FormSection title={t('When')}>
        <DateField label={t('Date & time')} value={new Date(r.due)} onChange={(d) => set('due', d.toISOString())} mode="datetime" />
        <Chips>{(['never', 'daily', 'weekly', 'monthly', 'yearly'] as RepeatRule[]).map((x) => <Chip key={x} label={t(cap(x))} selected={r.repeat === x} onPress={() => set('repeat', x)} />)}</Chips>
      </FormSection>
      <Field label={t('Notes')} value={r.notes} onChange={(v) => set('notes', v)} multiline />
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete reminder')} onPress={() => { getState().remove('reminders', r.id); cancelForItem(`reminder-${r.id}`); router.back(); }} />}
    </Screen>
  );
}

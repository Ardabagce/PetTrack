import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { kindIcon } from '@/components/petParts';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen, ToggleRow } from '@/components/ui';
import { atTime } from '@/lib/dates';
import { parseDecimal } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, requestPermission, scheduleSlot } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { FeedingKind, FeedingSlot } from '@/lib/types';

export default function SlotEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet } = useSelectedPet();
  const existing = useStore((s) => s.data.slots.find((x) => x.id === id));
  const [s, setS] = useState<FeedingSlot>(existing ?? { id: newId(), petId: pet!.id, label: '', kind: 'meal', hour: 8, minute: 0, food: '', portion: 0, enabled: true, notify: true });
  const [portion, setPortion] = useState(existing?.portion ? String(existing.portion) : '');
  const set = <K extends keyof FeedingSlot>(k: K, v: FeedingSlot[K]) => setS((x) => ({ ...x, [k]: v }));
  const kindLabel = (k: FeedingKind) => t(k === 'meal' ? 'Meal' : k === 'water' ? 'Water' : 'Treat');
  const save = () => {
    const next = { ...s, label: s.label.trim() || kindLabel(s.kind), portion: parseDecimal(portion) ?? 0, food: s.kind === 'water' ? '' : s.food };
    getState().upsert('slots', next);
    requestPermission().then(() => scheduleSlot(next, pet?.name ?? ''));
    router.back();
  };
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit feeding time' : 'New feeding time')} onSave={save} />
      <Chips>{(['meal', 'water', 'treat'] as FeedingKind[]).map((k) => <Chip key={k} icon={kindIcon[k]} label={kindLabel(k)} selected={s.kind === k} onPress={() => set('kind', k)} />)}</Chips>
      <FormSection>
        <Field label={t('Label (e.g. Breakfast)')} value={s.label} onChange={(v) => set('label', v)} />
        <DateField label={t('Time')} mode="time" value={atTime(new Date(), s.hour, s.minute)} onChange={(d) => setS((x) => ({ ...x, hour: d.getHours(), minute: d.getMinutes() }))} />
        {s.kind !== 'water' && <Field label={t('Food')} value={s.food} onChange={(v) => set('food', v)} />}
        <Field label={t('Portion')} value={portion} onChange={setPortion} keyboard="decimal-pad" suffix={s.kind === 'water' ? 'ml' : 'g'} placeholder={t('Optional')} />
        <ToggleRow label={t('Daily notification')} value={s.notify} onChange={(v) => set('notify', v)} />
      </FormSection>
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete feeding time')} onPress={() => { getState().remove('slots', s.id); cancelForItem(`slot-${s.id}`); router.back(); }} />}
    </Screen>
  );
}

import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen } from '@/components/ui';
import { addDays } from '@/lib/dates';
import { countryName } from '@/lib/format';
import { deviceRegion, useTranslation } from '@/lib/i18n';
import { cancelForItem, requestPermission, scheduleTravel } from '@/lib/notifications';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { DESTINATIONS } from '@/lib/travel';
import type { TravelPlan } from '@/lib/types';

export default function TravelEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { pet } = useSelectedPet();
  const existing = useStore((s) => s.data.travelPlans.find((x) => x.id === id));
  const [p, setP] = useState<TravelPlan>(existing ?? {
    id: newId(), petId: pet!.id, destination: deviceRegion() === 'US' ? 'DE' : 'US', departure: addDays(new Date(), 45).toISOString(), arrival: addDays(new Date(), 46).toISOString(), done: [], notes: '',
  });
  const set = <K extends keyof TravelPlan>(k: K, v: TravelPlan[K]) => setP((x) => ({ ...x, [k]: v }));
  const save = () => {
    getState().upsert('travelPlans', p);
    requestPermission().then(() => scheduleTravel(p, pet!, getState().data));
    if (existing) router.back(); else router.replace(`/travel/${p.id}`);
  };
  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit trip' : 'Plan a trip')} onSave={save} />
      <FormSection title={t('Destination')}>
        <Chips>{DESTINATIONS.map((d) => <Chip key={d.code} label={`${d.flag} ${countryName(d.code)}`} selected={p.destination === d.code} onPress={() => set('destination', d.code)} />)}</Chips>
      </FormSection>
      <FormSection footer={t('Deadlines are counted back from the arrival date.')}>
        <DateField label={t('Departure')} value={new Date(p.departure)} min={new Date()} onChange={(d) => setP((x) => ({ ...x, departure: d.toISOString(), arrival: d > new Date(x.arrival) ? d.toISOString() : x.arrival }))} />
        <DateField label={t('Arrival')} value={new Date(p.arrival)} min={new Date(p.departure)} onChange={(d) => set('arrival', d.toISOString())} />
      </FormSection>
      <Field label={t('Notes (flight, airline, address)')} value={p.notes} onChange={(v) => set('notes', v)} multiline />
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete trip')} onPress={() => { getState().remove('travelPlans', p.id); cancelForItem(`travel-${p.id}`); router.dismissAll(); }} />}
    </Screen>
  );
}

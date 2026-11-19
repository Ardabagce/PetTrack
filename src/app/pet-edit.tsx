import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Image, Pressable, View } from 'react-native';
import { DateField } from '@/components/extras';
import { Button, Chip, Chips, EditorHeader, Field, FormSection, Screen, T, ToggleRow, useConfirm } from '@/components/ui';
import { blankPet, rescheduleAll } from '@/lib/actions';
import { addYears } from '@/lib/dates';
import { parseDecimal, resolvedUnit, toKg, weightValue } from '@/lib/format';
import { tr, useTranslation } from '@/lib/i18n';
import { pickPhoto } from '@/lib/images';
import { requestPermission } from '@/lib/notifications';
import { cap } from '@/lib/pdf';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { Pet, Sex, Species } from '@/lib/types';

export default function PetEdit() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const existing = useStore((s) => s.data.pets.find((p) => p.id === id));
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const [pet, setPet] = useState<Pet>(existing ?? blankPet('', 'dog', getState().data.pets.length));
  const [hasBirth, setHasBirth] = useState(!!existing?.birthDate);
  const [target, setTarget] = useState(existing?.targetWeightKg ? String(Math.round(weightValue(existing.targetWeightKg, unit) * 10) / 10) : '');
  const { ask, dialog } = useConfirm();
  const set = <K extends keyof Pet>(k: K, v: Pet[K]) => setPet((p) => ({ ...p, [k]: v }));

  const save = () => {
    const { upsert, upsertMany, setSettings } = getState();
    const kg = parseDecimal(target);
    const next: Pet = { ...pet, name: pet.name.trim(), birthDate: hasBirth ? pet.birthDate ?? addYears(new Date(), -1).toISOString() : undefined, targetWeightKg: kg ? toKg(kg, unit) : undefined };
    upsert('pets', next);
    if (!existing) {
      setSettings({ selectedPetId: next.id });
      if (next.species === 'dog' || next.species === 'cat') {
        upsertMany('slots', [
          { id: newId(), petId: next.id, label: tr('Breakfast'), kind: 'meal', hour: 8, minute: 0, food: '', portion: 0, enabled: true, notify: true },
          { id: newId(), petId: next.id, label: tr('Fresh water'), kind: 'water', hour: 9, minute: 0, food: '', portion: 0, enabled: true, notify: true },
          { id: newId(), petId: next.id, label: tr('Dinner'), kind: 'meal', hour: 18, minute: 0, food: '', portion: 0, enabled: true, notify: true },
        ]);
      }
    }
    requestPermission().then(() => rescheduleAll(next.id));
    if (router.canGoBack()) router.back(); else router.replace('/');
  };

  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit pet' : 'New pet')} onSave={save} canSave={pet.name.trim().length > 0} />
      {dialog}
      <View style={{ alignItems: 'center', gap: 14 }}>
        <Pressable onPress={async () => { const p = await pickPhoto('library', 900); if (p) set('photo', p); }} accessibilityRole="button" accessibilityLabel={t('Photos')}>
          {pet.photo
            ? <Image source={{ uri: pet.photo }} style={{ width: 112, height: 112, borderRadius: 56 }} />
            : <View style={{ width: 112, height: 112, borderRadius: 56, backgroundColor: c.surfaceMuted, alignItems: 'center', justifyContent: 'center' }}><Ionicons name="paw" size={40} color={c.ink3} /></View>}
          <View style={{ position: 'absolute', right: 0, bottom: 0, width: 34, height: 34, borderRadius: 17, backgroundColor: c.ink, alignItems: 'center', justifyContent: 'center', borderWidth: 3, borderColor: c.canvas }}>
            <Ionicons name="camera" size={15} color={c.canvas} />
          </View>
        </Pressable>
      </View>
      <Field value={pet.name} onChange={(v) => set('name', v)} placeholder={t('Name')} big autoFocus={!existing} />
      <Chips>
        {(['dog', 'cat', 'rabbit', 'bird', 'other'] as Species[]).map((s) => <Chip key={s} label={t(cap(s))} selected={pet.species === s} onPress={() => set('species', s)} />)}
      </Chips>
      <FormSection title={t('Basics')}>
        <Field label={t('Breed')} value={pet.breed} onChange={(v) => set('breed', v)} />
        <T variant="caption">{t('Sex')}</T>
        <Chips>{(['female', 'male', 'unknown'] as Sex[]).map((s) => <Chip key={s} label={t(cap(s))} selected={pet.sex === s} onPress={() => set('sex', s)} />)}</Chips>
        <ToggleRow label={t('Spayed / neutered')} value={pet.neutered} onChange={(v) => set('neutered', v)} />
        <ToggleRow label={t('Birthday known')} value={hasBirth} onChange={setHasBirth} />
        {hasBirth && <DateField label={t('Birthday')} value={new Date(pet.birthDate ?? addYears(new Date(), -1))} max={new Date()} onChange={(d) => set('birthDate', d.toISOString())} />}
        <Field label={t('Target weight')} value={target} onChange={setTarget} keyboard="decimal-pad" suffix={unit} placeholder={t('Optional')} />
      </FormSection>
      <FormSection title={t('Emergency information')} footer={t('Shown on the emergency card and included in the health passport.')}>
        <Field label={t('Microchip number')} value={pet.microchip} onChange={(v) => set('microchip', v)} keyboard="number-pad" />
        <Field label={t('Blood type')} value={pet.bloodType} onChange={(v) => set('bloodType', v)} />
        <Field label={t('Allergies')} value={pet.allergies} onChange={(v) => set('allergies', v)} multiline />
        <Field label={t('Chronic conditions')} value={pet.conditions} onChange={(v) => set('conditions', v)} multiline />
        <Field label={t('Emergency notes')} value={pet.emergencyNotes} onChange={(v) => set('emergencyNotes', v)} multiline />
      </FormSection>
      <FormSection title={t('Veterinarian')}>
        <Field label={t('Clinic')} value={pet.vetClinic} onChange={(v) => set('vetClinic', v)} />
        <Field label={t('Veterinarian')} value={pet.vetName} onChange={(v) => set('vetName', v)} />
        <Field label={t('Phone')} value={pet.vetPhone} onChange={(v) => set('vetPhone', v)} keyboard="phone-pad" />
        <Field label={t('Email')} value={pet.vetEmail} onChange={(v) => set('vetEmail', v)} keyboard="email-address" />
      </FormSection>
      <FormSection title={t('Insurance')}>
        <Field label={t('Provider')} value={pet.insuranceProvider} onChange={(v) => set('insuranceProvider', v)} />
        <Field label={t('Policy number')} value={pet.insurancePolicy} onChange={(v) => set('insurancePolicy', v)} />
      </FormSection>
      {existing && (
        <Button title={t('Delete pet')} variant="soft" tint={c.danger} onPress={() => ask({
          title: t('Delete pet?'), message: t('This permanently removes the pet and all of its health records.'), confirm: t('Delete all records'), destructive: true,
          onConfirm: () => { getState().deletePet(existing.id); router.back(); },
        })} />
      )}
    </Screen>
  );
}

import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { Banner, Button, Card, Chip, Chips, EditorHeader, Field, FormSection, Row, Screen, T } from '@/components/ui';
import { formatWeight, parseDecimal, resolvedUnit } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import { type Activity, ageInYears, BCS_LABELS, portionPlan } from '@/lib/wellness';

/** Body condition check + daily calories + grams per meal, applied to the feeding schedule in one tap. */
export default function Portions() {
  const c = useTheme();
  const { t } = useTranslation();
  const view = useSelectedPet();
  const pet = view.pet!;
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const lastBcs = useStore((s) => s.data.bcs.filter((b) => b.petId === pet.id).sort((a, b) => b.date.localeCompare(a.date))[0]);
  const [bcs, setBcs] = useState(lastBcs?.score ?? 5);
  const [activity, setActivity] = useState<Activity>(pet.activity ?? 'normal');
  const [kcal, setKcal] = useState(pet.foodKcal100g ? String(pet.foodKcal100g) : '');
  const meals = view.slots.filter((s) => s.enabled && s.kind === 'meal');
  const kg = view.latestWeight?.kg;
  const plan = kg ? portionPlan({
    species: pet.species, kg, bcs, neutered: pet.neutered, activity, kcalPer100g: parseDecimal(kcal),
    ageYears: pet.birthDate ? ageInYears(pet.birthDate) : undefined, meals: Math.max(1, meals.length),
  }) : undefined;
  const bcsColor = bcs <= 3 ? c.sky : bcs <= 5 ? c.sage : bcs <= 6 ? c.butter : c.danger;

  const apply = () => {
    const { upsert } = getState();
    upsert('bcs', { id: newId(), petId: pet.id, date: new Date().toISOString(), score: bcs });
    upsert('pets', { ...pet, activity, foodKcal100g: parseDecimal(kcal) });
    router.back();
  };

  return (
    <Screen modal>
      <EditorHeader title={t('Portion estimate')} onSave={apply} />
      <Banner icon="information-circle-outline" tint={c.sky} text={t('A general estimate from published formulas – not a feeding plan or veterinary advice. Needs vary with health, breed and food. Agree portions and any weight change with your vet.')} />
      {!kg && <Banner icon="barbell-outline" tint={c.butter} text={t('Log a weight first – the calculation starts from it.')} />}
      <FormSection title={t('Body condition score')} footer={t('Look from above and from the side, then feel the ribs with flat hands.')}>
        <Row gap={4}>
          {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => (
            <Pressable key={n} onPress={() => setBcs(n)} accessibilityRole="radio" accessibilityState={{ checked: bcs === n }} accessibilityLabel={`${n}: ${t(BCS_LABELS[n].title)}`}
              style={{ flex: 1, height: 44, borderRadius: 10, alignItems: 'center', justifyContent: 'center', backgroundColor: bcs === n ? bcsColor : c.surfaceMuted }}>
              <T variant="headline" color={bcs === n ? '#fff' : c.ink2} style={{ fontSize: 15 }}>{n}</T>
            </Pressable>
          ))}
        </Row>
        <BodyShape score={bcs} color={bcsColor} />
        <T variant="headline" color={bcsColor}>{bcs} · {t(BCS_LABELS[bcs].title)}</T>
        <T variant="sub">{t(BCS_LABELS[bcs].hint)}</T>
      </FormSection>
      <FormSection title={t('Activity')}>
        <Chips>{(['low', 'normal', 'high'] as Activity[]).map((a) => <Chip key={a} label={t(a === 'low' ? 'Couch potato' : a === 'normal' ? 'Normal' : 'Very active')} selected={activity === a} onPress={() => setActivity(a)} />)}</Chips>
        <Field label={t('Food energy (kcal per 100 g)')} value={kcal} onChange={setKcal} keyboard="decimal-pad" suffix="kcal" placeholder={t('On the bag, e.g. 365')} />
      </FormSection>
      {plan && kg && (
        <Card tone="forest">
          <T variant="eyebrow" color="#F6F0E499">{t('Daily plan for {{a}}', { a: pet.name })}</T>
          <Row gap={10}>
            {[
              [`${plan.kcalPerDay}`, t('kcal per day')],
              [plan.gramsPerDay ? `${plan.gramsPerDay} g` : '—', t('per day')],
              [plan.gramsPerMeal ? `${plan.gramsPerMeal} g` : '—', t('per meal ({{a}}×)', { a: Math.max(1, meals.length) })],
            ].map(([v, l]) => (
              <View key={l} style={{ flex: 1, backgroundColor: '#F6F0E414', borderRadius: radius.medium, padding: 12 }}>
                <T variant="display" color={c.cream} style={{ fontSize: 24 }}>{v}</T>
                <T variant="caption" color="#F6F0E4A6">{l}</T>
              </View>
            ))}
          </Row>
          <T color={c.cream}>{bcs === 5 ? t('{{a}} looks to be at a healthy body condition.', { a: pet.name })
            : t('Rough ideal-weight estimate: {{a}} (now {{b}}). Ask your vet to confirm.', { a: formatWeight(plan.idealKg, unit), b: formatWeight(kg, unit) })}</T>
        </Card>
      )}
      <T variant="caption" center>{t('Based on WSAVA / AAHA feeding guidelines. Treats should be under 10% of daily calories. Ask your vet before a diet.')}</T>
      <Button title={t('Save body condition')} tint={c.accent} onPress={apply} />
    </Screen>
  );
}

/** Simple top-down body silhouette that widens with the score. */
function BodyShape({ score, color }: { score: number; color: string }) {
  const c = useTheme();
  const waist = 26 + score * 6;
  return (
    <View style={{ alignItems: 'center', paddingVertical: 6 }} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <View style={{ flexDirection: 'row', alignItems: 'center' }}>
        <View style={{ width: 34, height: 30, borderRadius: 15, backgroundColor: c.surfaceMuted }} />
        <View style={{ width: 46, height: 52, borderRadius: 22, backgroundColor: c.surfaceMuted, marginLeft: -4 }} />
        <View style={{ width: 54, height: waist, borderRadius: waist / 2, backgroundColor: color, opacity: 0.85, marginLeft: -6 }} />
        <View style={{ width: 46, height: 50, borderRadius: 22, backgroundColor: c.surfaceMuted, marginLeft: -6 }} />
        <View style={{ width: 40, height: 6, borderRadius: 3, backgroundColor: c.surfaceMuted, marginLeft: -4 }} />
      </View>
    </View>
  );
}

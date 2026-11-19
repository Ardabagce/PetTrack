import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { View } from 'react-native';
import { FREE_LIMITS, requirePremium } from '@/lib/premium';
import { ageText, formatSlotTime, formatWeight, resolvedUnit } from '@/lib/format';
import { ageInYears, humanYears, lifeStage } from '@/lib/wellness';
import { useTranslation } from '@/lib/i18n';
import { type PetView, useSelectedPet, usePremium, vaccineStatus } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { fonts, petColors, radius, useTheme } from '@/lib/theme';
import { PetAvatar, PetSwitcher, Row, T } from './ui';

/** Pet selector used at the top of every tab. */
export function TabPetSwitcher() {
  const { pets, pet } = useSelectedPet();
  const premium = usePremium();
  const setSettings = useStore((s) => s.setSettings);
  return (
    <PetSwitcher
      pets={pets} selectedId={pet?.id} onSelect={(id) => setSettings({ selectedPetId: id })}
      onAdd={() => (pets.length >= FREE_LIMITS.pets && !premium ? requirePremium('unlimitedPets', () => {}) : router.push('/pet-edit'))}
    />
  );
}

export function PetHero({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const pet = view.pet!;
  const attention = view.vaccinations.filter((v) => vaccineStatus(v) !== 'upToDate').length;
  const nowMin = new Date().getHours() * 60 + new Date().getMinutes();
  const meals = view.slots.filter((s) => s.enabled && s.kind === 'meal');
  const next = meals.find((s) => s.hour * 60 + s.minute > nowMin) ?? meals[0];
  const years = pet.birthDate ? ageInYears(pet.birthDate) : undefined;
  const human = years !== undefined ? humanYears(pet.species, years, view.latestWeight?.kg) : undefined;
  const stage = years !== undefined ? lifeStage(pet.species, years, view.latestWeight?.kg) : undefined;
  const stat = (icon: keyof typeof Ionicons.glyphMap, value: string, label: string) => (
    <View style={{ flex: 1, backgroundColor: '#F6F0E414', borderRadius: radius.medium, padding: 12, gap: 4 }} accessible accessibilityLabel={`${label}: ${value}`}>
      <Ionicons name={icon} size={14} color="#F6F0E499" />
      <T variant="number" color={c.cream} numberOfLines={1} style={{ fontSize: 16 }}>{value}</T>
      <T variant="caption" color="#F6F0E499" style={{ fontSize: 11 }}>{label}</T>
    </View>
  );
  return (
    <View style={{ borderRadius: radius.card + 4, overflow: 'hidden' }}>
      <LinearGradient colors={[c.forest, c.forestDeep]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ padding: 20, gap: 18 }}>
        <View style={{ position: 'absolute', right: -60, top: -80, width: 220, height: 220, borderRadius: 110, backgroundColor: petColors(c)[pet.colorIndex % 5], opacity: 0.18 }} />
        <Row gap={14}>
          <PetAvatar pet={pet} size={64} />
          <View style={{ flex: 1 }}>
            <T variant="display" color={c.cream} style={{ fontSize: 30 }}>{pet.name}</T>
            <T variant="sub" color="#F6F0E4B3" numberOfLines={1}>{[pet.breed || t(pet.species.charAt(0).toUpperCase() + pet.species.slice(1)), ageText(pet.birthDate)].filter(Boolean).join(' · ')}</T>
            {human !== undefined && stage && (
              <T variant="caption" color="#F6F0E499">{t('≈ {{a}} in human years · {{b}}', { a: human, b: t(LIFE_STAGE[stage]) })}</T>
            )}
          </View>
        </Row>
        <Row gap={10}>
          {stat('barbell-outline', view.latestWeight ? formatWeight(view.latestWeight.kg, unit) : '—', t('Weight'))}
          {stat('medkit-outline', view.vaccinations.length === 0 ? '—' : attention === 0 ? t('All set') : t('{{a}} due', { a: attention }), t('Vaccines'))}
          {stat('restaurant-outline', next ? formatSlotTime(next.hour, next.minute) : '—', t('Next meal'))}
        </Row>
      </LinearGradient>
    </View>
  );
}

const LIFE_STAGE = { baby: 'Baby', junior: 'Junior', adult: 'Adult', mature: 'Mature adult', senior: 'Senior' } as const;

export const kindIcon = { meal: 'restaurant', water: 'water', treat: 'star' } as const;
export function kindColor(c: ReturnType<typeof useTheme>, kind: 'meal' | 'water' | 'treat') {
  return kind === 'meal' ? c.butter : kind === 'water' ? c.sky : c.plum;
}
export const fontsRef = fonts;

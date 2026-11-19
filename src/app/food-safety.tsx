import Ionicons from '@expo/vector-icons/Ionicons';
import { useMemo, useState } from 'react';
import { Linking, Pressable, View } from 'react-native';
import { Banner, Card, Chip, Chips, Field, Pill, Row, Screen, T } from '@/components/ui';
import { FOOD_ITEMS, hotlines, itemName, LEVEL_ORDER, LEVEL_TITLE, levelFor, searchFoods, type SafetyLevel } from '@/lib/foodSafety';
import { deviceRegion, useTranslation } from '@/lib/i18n';
import { cap } from '@/lib/pdf';
import { useSelectedPet } from '@/lib/selectors';
import { useTheme } from '@/lib/theme';
import type { Species } from '@/lib/types';

/** Offline "Can my pet eat this?" lookup with emergency numbers. */
export default function FoodSafety() {
  const c = useTheme();
  const { t, i18n } = useTranslation();
  const { pet } = useSelectedPet();
  const [query, setQuery] = useState('');
  const [species, setSpecies] = useState<Species>(pet?.species === 'cat' ? 'cat' : 'dog');
  const [open, setOpen] = useState<string | null>(null);
  const colors: Record<SafetyLevel, string> = { safe: c.sage, caution: c.butter, toxic: c.accent, emergency: c.danger };
  const icons: Record<SafetyLevel, keyof typeof Ionicons.glyphMap> = { safe: 'checkmark-circle', caution: 'alert-circle', toxic: 'close-circle', emergency: 'warning' };
  const results = useMemo(() => searchFoods(query).slice().sort((a, b) => LEVEL_ORDER.indexOf(levelFor(b, species)) - LEVEL_ORDER.indexOf(levelFor(a, species))), [query, species]);
  const lines = hotlines(deviceRegion());

  return (
    <Screen title={t('Can my pet eat this?')}>
      <Field value={query} onChange={setQuery} placeholder={t('Search: chocolate, grapes, lilies…')} />
      <Chips>{(['dog', 'cat'] as Species[]).map((s) => <Chip key={s} label={t(cap(s))} selected={species === s} onPress={() => setSpecies(s)} />)}</Chips>
      <Card tone="danger">
        <Row><Ionicons name="call" size={18} color={c.danger} /><T variant="headline">{t('Ate something dangerous?')}</T></Row>
        <T variant="sub">{t("Call your vet or the nearest emergency clinic right away. Don't make your pet vomit unless a vet tells you to. Keep the packaging.")}</T>
        {lines.map((h) => (
          <Pressable key={h.id} onPress={() => Linking.openURL(`tel:${h.phone.replace(/[^\d+]/g, '')}`)} accessibilityRole="button">
            <Row style={{ justifyContent: 'space-between' }}>
              <View style={{ flex: 1 }}><T variant="headline" style={{ fontSize: 15 }}>{h.name}</T><T variant="caption">{t(h.note)}</T></View>
              <T variant="number" color={c.danger}>{h.phone}</T>
            </Row>
          </Pressable>
        ))}
        {!!pet?.vetPhone && (
          <Pressable onPress={() => Linking.openURL(`tel:${pet.vetPhone.replace(/[^\d+]/g, '')}`)} accessibilityRole="button">
            <Row style={{ justifyContent: 'space-between' }}><T variant="headline" style={{ fontSize: 15 }}>{pet.vetClinic || t('Veterinarian')}</T><T variant="number" color={c.danger}>{pet.vetPhone}</T></Row>
          </Pressable>
        )}
      </Card>
      {results.length === 0 && <Banner icon="help-circle-outline" tint={c.ink2} text={t('Not in our list. When in doubt, ask your vet before feeding it.')} />}
      {results.map((item) => {
        const level = levelFor(item, species);
        const expanded = open === item.id;
        return (
          <Card key={item.id} padding={14} onPress={() => setOpen(expanded ? null : item.id)} accessibilityLabel={`${itemName(item, i18n.language)}: ${t(LEVEL_TITLE[level])}`}>
            <Row gap={12}>
              <Ionicons name={icons[level]} size={24} color={colors[level]} />
              <T variant="headline" style={{ flex: 1 }}>{itemName(item, i18n.language)}</T>
              <Pill text={t(LEVEL_TITLE[level].split(' – ')[0])} tint={colors[level]} />
            </Row>
            {expanded && <T variant="sub">{t(item.note)}</T>}
          </Card>
        );
      })}
      <T variant="caption" center>{t('{{a}} items · Sources: ASPCA Animal Poison Control, Pet Poison Helpline. A first-aid guide, not a diagnosis.', { a: FOOD_ITEMS.length })}</T>
    </Screen>
  );
}

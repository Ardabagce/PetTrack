import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, Switch, View } from 'react-native';
import { MixBar } from '@/components/extras';
import { kindColor, kindIcon, TabPetSwitcher } from '@/components/petParts';
import { Card, EmptyState, IconBadge, ProBadge, Row, SectionHeader, T, TabScreen, useConfirm } from '@/components/ui';
import { conflictMessage, logFeeding } from '@/lib/actions';
import { newFoodRatio, transitionDay } from '@/lib/diet';
import { formatSlotTime, relativeTime } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { scheduleSlot } from '@/lib/notifications';
import { FREE_LIMITS, requirePremium } from '@/lib/premium';
import { type PetView, logsToday, recentConflict, useSelectedPet, usePremium } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import type { FeedingKind } from '@/lib/types';

export default function Nutrition() {
  const { t } = useTranslation();
  const view = useSelectedPet();
  if (!view.pet) return null;
  return (
    <TabScreen title={t('Nutrition')}>
      <TabPetSwitcher />
      <Intake view={view} />
      <FoodSafetyEntry />
      <Schedule view={view} />
      <Transition view={view} />
      <Recent view={view} />
    </TabScreen>
  );
}

function Intake({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const { ask, dialog } = useConfirm();
  const today = logsToday(view.logs);
  const pet = view.pet!;
  const log = (kind: FeedingKind) => {
    const conflict = recentConflict(view.logs, kind);
    if (conflict) ask({ title: t('Already fed?'), message: conflictMessage(conflict, pet.name), confirm: t('Log anyway'), onConfirm: () => logFeeding(pet, kind) });
    else logFeeding(pet, kind);
  };
  return (
    <Card>
      {dialog}
      <T variant="eyebrow">{t('Today')}</T>
      <Row gap={10}>
        {(['meal', 'water', 'treat'] as const).map((kind) => {
          const tint = kindColor(c, kind);
          const count = today.filter((l) => l.kind === kind).length;
          const planned = view.slots.filter((s) => s.enabled && s.kind === kind).length;
          const label = t(kind === 'meal' ? 'Meal' : kind === 'water' ? 'Water' : 'Treat');
          return (
            <Pressable key={kind} onPress={() => log(kind)} accessibilityRole="button" accessibilityLabel={t('Log {{a}}', { a: label })} accessibilityHint={`${count}`}
              style={({ pressed }) => ({ flex: 1, backgroundColor: `${tint}1C`, borderRadius: radius.medium, padding: 14, gap: 8, transform: [{ scale: pressed ? 0.97 : 1 }] })}>
              <Row style={{ justifyContent: 'space-between' }}><Ionicons name={kindIcon[kind]} size={18} color={tint} /><Ionicons name="add" size={16} color={tint} /></Row>
              <Row gap={2} align="flex-end"><T variant="display" style={{ fontSize: 28, lineHeight: 32 }}>{count}</T>{planned > 0 && kind !== 'treat' && <T variant="caption" color={c.ink3}>/{planned}</T>}</Row>
              <T variant="caption">{label}</T>
            </Pressable>
          );
        })}
      </Row>
    </Card>
  );
}

function FoodSafetyEntry() {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <Card onPress={() => router.push('/food-safety')}>
      <Row gap={14}>
        <IconBadge icon="warning" tint={c.danger} size={46} />
        <View style={{ flex: 1 }}>
          <T variant="headline">{t('Can my pet eat this?')}</T>
          <T variant="caption">{t('Check foods, plants and household items – works offline, with emergency numbers.')}</T>
        </View>
        <Ionicons name="chevron-forward" size={18} color={c.ink3} />
      </Row>
    </Card>
  );
}

function Schedule({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const upsert = useStore((s) => s.upsert);
  return (
    <>
      <SectionHeader title={t('Feeding schedule')} action={t('Add')} onAction={() =>
        view.slots.length >= FREE_LIMITS.slots && !premium ? requirePremium('unlimitedReminders', () => {}) : router.push('/slot')} />
      {view.slots.length === 0
        ? <EmptyState icon="time-outline" title={t('No feeding times')} message={t("Set meal and water times and we'll remind you every day.")} />
        : (
          <Card padding={14}>
            {view.slots.map((slot) => (
              <Row key={slot.id} gap={12} style={{ minHeight: 56 }}>
                <Pressable style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 12 }} onPress={() => router.push({ pathname: '/slot', params: { id: slot.id } })} accessibilityRole="button">
                  <IconBadge icon={kindIcon[slot.kind]} tint={kindColor(c, slot.kind)} />
                  <View style={{ flex: 1 }}>
                    <T variant="headline" style={{ fontSize: 15 }}>{slot.label}</T>
                    <T variant="caption" numberOfLines={1}>{[slot.food, slot.portion ? `${slot.portion} ${slot.kind === 'water' ? 'ml' : 'g'}` : ''].filter(Boolean).join(' · ') || t(slot.kind === 'water' ? 'Water' : 'Meal')}</T>
                  </View>
                  <T variant="number" color={slot.enabled ? c.ink : c.ink3} style={{ fontSize: 16 }}>{formatSlotTime(slot.hour, slot.minute)}</T>
                </Pressable>
                <Switch value={slot.enabled} trackColor={{ true: c.sage, false: c.surfaceMuted }} accessibilityLabel={slot.label}
                  onValueChange={(enabled) => { const next = { ...slot, enabled }; upsert('slots', next); scheduleSlot(next, view.pet!.name); }} />
              </Row>
            ))}
          </Card>
        )}
    </>
  );
}

function Transition({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const tr = view.activeTransition;
  if (tr) {
    const day = transitionDay(tr);
    return (
      <>
        <SectionHeader title={t('Food transition')} action={t('Edit')} onAction={() => router.push({ pathname: '/transition', params: { id: tr.id } })} />
        <Card>
          <T variant="headline">{tr.fromFood} → {tr.toFood}</T>
          <T variant="caption">{t('Day {{a}} of {{b}}', { a: Math.min(day + 1, tr.days), b: tr.days })}</T>
          <MixBar ratio={newFoodRatio(day, tr.days)} newFood={tr.toFood} oldFood={tr.fromFood} />
          <Row gap={4} align="flex-end" style={{ height: 44 }}>
            {Array.from({ length: tr.days }, (_, i) => {
              const r = newFoodRatio(i, tr.days);
              return (
                <View key={i} style={{ flex: 1, alignItems: 'center', gap: 4 }}>
                  <View style={{ width: '100%', height: 6 + r * 24, borderRadius: 4, backgroundColor: c.butter, opacity: 0.3 + r * 0.7 }} />
                  <T variant="caption" color={i === day ? c.ink : c.ink3} style={{ fontSize: 10 }}>{i + 1}</T>
                </View>
              );
            })}
          </Row>
        </Card>
      </>
    );
  }
  return (
    <Card onPress={() => requirePremium('dietTransition', () => router.push('/transition'))}>
      <Row gap={14}>
        <IconBadge icon="swap-horizontal" tint={c.butter} size={46} />
        <View style={{ flex: 1, gap: 3 }}>
          <Row gap={6}><T variant="headline">{t('Switching food?')}</T>{!premium && <ProBadge />}</Row>
          <T variant="caption">{t('Get a gentle day-by-day mixing plan to avoid upset tummies.')}</T>
        </View>
        <Ionicons name="chevron-forward" size={18} color={c.ink3} />
      </Row>
    </Card>
  );
}

function Recent({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const remove = useStore((s) => s.remove);
  const logs = view.logs.slice(0, 12);
  return (
    <>
      <SectionHeader title={t('Recent activity')} />
      <Card padding={14}>
        {logs.length === 0 && <T variant="sub">{t('Logged meals, water and treats will appear here.')}</T>}
        {logs.map((l) => (
          <Row key={l.id} gap={12} style={{ minHeight: 40 }}>
            <Ionicons name={kindIcon[l.kind]} size={16} color={kindColor(c, l.kind)} style={{ width: 22 }} />
            <T style={{ fontSize: 15 }}>{t(l.kind === 'meal' ? 'Meal' : l.kind === 'water' ? 'Water' : 'Treat')}</T>
            {!!l.fedBy && <T variant="caption">{l.fedBy}</T>}
            {l.source === 'household' && <Ionicons name="people" size={14} color={c.sky} accessibilityLabel={t('Family')} />}
            <View style={{ flex: 1 }} />
            <T variant="caption" color={c.ink3}>{relativeTime(l.date)}</T>
            <Pressable onPress={() => remove('logs', l.id)} hitSlop={8} accessibilityRole="button" accessibilityLabel={t('Delete')}>
              <Ionicons name="close" size={16} color={c.ink3} />
            </Pressable>
          </Row>
        ))}
      </Card>
    </>
  );
}

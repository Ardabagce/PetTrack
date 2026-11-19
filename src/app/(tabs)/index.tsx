import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useEffect } from 'react';
import { Image, Pressable, View } from 'react-native';
import { LineChart, MixBar } from '@/components/extras';
import { kindColor, kindIcon, PetHero, TabPetSwitcher } from '@/components/petParts';
import { Card, Columns, IconBadge, IconButton, Row, T, TabScreen, useConfirm } from '@/components/ui';
import { completeReminder, conflictMessage, logFeeding } from '@/lib/actions';
import { addDays, atTime, daysBetween, isSameDay } from '@/lib/dates';
import { newFoodRatio, transitionDay } from '@/lib/diet';
import { countryName, formatDate, formatSlotTime, formatTime, formatWeight, relativeDay, resolvedUnit } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { type PetView, logsToday, recentConflict, useSelectedPet, vaccineStatus } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { FeedingLog, FeedingSlot } from '@/lib/types';

export default function Today() {
  const c = useTheme();
  const { t } = useTranslation();
  const view = useSelectedPet();
  const tourDone = useStore((s) => s.settings.tourDone);

  useEffect(() => {
    if (!tourDone) setTimeout(() => router.push('/tour'), 400);
  }, [tourDone]);

  const hour = new Date().getHours();
  const greeting = hour < 5 ? 'Good evening' : hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  if (!view.pet) return null;

  return (
    <TabScreen title={t(greeting)} right={<IconButton icon="settings-outline" label={t('Settings')} onPress={() => router.push('/settings')} />}>
      <T variant="eyebrow" style={{ marginTop: -12 }}>{formatDate(new Date(), 'full')}</T>
      <TabPetSwitcher />
      {view.pet.lost?.active && (
        <Card tone="danger" onPress={() => router.push('/lost')}>
          <Row><Ionicons name="alert-circle" size={22} color={c.danger} /><T variant="headline" style={{ flex: 1 }}>{t('{{a}} is marked as lost', { a: view.pet.name })}</T></Row>
          <T variant="sub">{t('Your collar QR page shows the lost-pet alert. Tap to update or mark as found.')}</T>
        </Card>
      )}
      <Columns
        left={<>
          <PetHero view={view} />
          <FeedingCard view={view} />
        </>}
        right={<>
        {view.openSymptomCases.length > 0 && <SymptomWatch view={view} />}
        <Upcoming view={view} />
        {view.activeTransition && (
          <Card onPress={() => router.push('/nutrition')}>
            <Row><IconBadge icon="swap-horizontal" tint={c.butter} size={36} />
              <View><T variant="headline">{t('Food transition')}</T>
                <T variant="caption">{t('Day {{a}} of {{b}}', { a: Math.min(transitionDay(view.activeTransition) + 1, view.activeTransition.days), b: view.activeTransition.days })}</T></View></Row>
            <MixBar ratio={newFoodRatio(transitionDay(view.activeTransition), view.activeTransition.days)} newFood={view.activeTransition.toFood} oldFood={view.activeTransition.fromFood} />
          </Card>
        )}
        <WeightCard view={view} />
        </>}
      />
    </TabScreen>
  );
}

function FeedingCard({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const { ask, dialog } = useConfirm();
  const remove = useStore((s) => s.remove);
  const slots = view.slots.filter((s) => s.enabled);
  const today = logsToday(view.logs);
  const pet = view.pet!;

  const logFor = (slot: FeedingSlot): FeedingLog | undefined =>
    today.find((l) => l.slotId === slot.id) ??
    today.find((l) => !l.slotId && l.kind === slot.kind && Math.abs(new Date(l.date).getTime() - atTime(new Date(), slot.hour, slot.minute).getTime()) < 90 * 60_000);

  const toggle = (slot: FeedingSlot, existing?: FeedingLog) => {
    if (existing) { remove('logs', existing.id); return; }
    const conflict = recentConflict(view.logs, slot.kind, new Date(), slot.id);
    const commit = () => logFeeding(pet, slot.kind, { amount: slot.portion, slotId: slot.id });
    if (conflict) ask({ title: t('Already fed?'), message: conflictMessage(conflict, pet.name), confirm: t('Log anyway'), onConfirm: commit });
    else commit();
  };

  const done = slots.filter((s) => logFor(s)).length;
  return (
    <Card>
      {dialog}
      <Row style={{ justifyContent: 'space-between' }}>
        <T variant="title">{t('Meals & water')}</T>
        <T variant="number" color={c.ink2}>{done}/{slots.length}</T>
      </Row>
      {slots.length === 0 && <T variant="sub">{t('No feeding times yet. Add them in Nutrition.')}</T>}
      {slots.map((slot, i) => {
        const log = logFor(slot);
        const tint = kindColor(c, slot.kind);
        return (
          <Row key={slot.id} gap={14} style={{ minHeight: 52 }}>
            <View style={{ width: 12, alignItems: 'center', alignSelf: 'stretch' }}>
              <View style={{ width: 12, height: 12, borderRadius: 6, marginTop: 20, backgroundColor: log ? tint : 'transparent', borderWidth: log ? 0 : 1.5, borderColor: tint }} />
              {i < slots.length - 1 && <View style={{ flex: 1, width: 1.5, backgroundColor: c.hairline }} />}
            </View>
            <View style={{ flex: 1 }}>
              <T variant="headline" style={{ fontSize: 15, textDecorationLine: log ? 'line-through' : 'none', color: log ? c.ink3 : c.ink }}>{slot.label}</T>
              <T variant="caption">
                {log ? t('{{a}} at {{b}}', { a: log.fedBy || t('Done'), b: formatTime(log.date) }) : [formatSlotTime(slot.hour, slot.minute), slot.food].filter(Boolean).join(' · ')}
              </T>
            </View>
            <Pressable onPress={() => toggle(slot, log)} accessibilityRole="checkbox" accessibilityState={{ checked: !!log }} accessibilityLabel={slot.label}
              style={{ width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center', backgroundColor: log ? `${tint}22` : c.surfaceMuted }}>
              <Ionicons name={log ? 'checkmark' : kindIcon[slot.kind]} size={20} color={log ? tint : c.ink3} />
            </Pressable>
          </Row>
        );
      })}
    </Card>
  );
}

function SymptomWatch({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <Card>
      <T variant="eyebrow">{t('Watching')}</T>
      {view.openSymptomCases.map((sc) => {
        const entries = view.entriesFor(sc);
        const last = entries.at(-1);
        const doneToday = entries.some((e) => isSameDay(e.date, new Date()));
        return (
          <Row key={sc.id} gap={12}>
            <Pressable style={{ flex: 1, flexDirection: 'row', gap: 12, alignItems: 'center' }} onPress={() => router.push(`/symptom/${sc.id}`)} accessibilityRole="button">
              {last?.photo ? <Image source={{ uri: last.photo }} style={{ width: 44, height: 44, borderRadius: 12 }} /> : <IconBadge icon="camera-outline" tint={c.ink3} size={44} />}
              <View style={{ flex: 1 }}>
                <T variant="headline" style={{ fontSize: 15 }} numberOfLines={1}>{sc.title}</T>
                <T variant="caption">{t('Day {{a}}', { a: daysBetween(sc.start, new Date()) + 1 })}</T>
              </View>
            </Pressable>
            {doneToday
              ? <Ionicons name="checkmark-circle" size={26} color={c.sage} accessibilityLabel={t('Done')} />
              : <IconButton icon="camera" label={t("Today's photo")} tint={c.accent} bg={`${c.accent}22`} onPress={() => router.push({ pathname: '/symptom-entry', params: { caseId: sc.id } })} />}
          </Row>
        );
      })}
    </Card>
  );
}

function Upcoming({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const horizon = addDays(new Date(), 60);
  type Item = { id: string; icon: keyof typeof Ionicons.glyphMap; tint: string; title: string; date: Date; onPress?: () => void; onDone?: () => void };
  const items: Item[] = [
    ...view.vaccinations.filter((v) => v.nextDue && new Date(v.nextDue) <= horizon).map((v): Item => ({
      id: v.id, icon: 'medkit', tint: vaccineStatus(v) === 'overdue' ? c.danger : vaccineStatus(v) === 'dueSoon' ? c.butter : c.sage,
      title: v.name, date: new Date(v.nextDue!), onPress: () => router.push({ pathname: '/vaccine', params: { id: v.id } }),
    })),
    ...view.reminders.map((r): Item => ({
      id: r.id, icon: 'notifications', tint: c.plum, title: r.title, date: new Date(r.due),
      onPress: () => router.push({ pathname: '/reminder', params: { id: r.id } }), onDone: () => completeReminder(r, view.pet!.name),
    })),
    ...view.visits.filter((v) => v.followUp && new Date(v.followUp) >= addDays(new Date(), -1) && new Date(v.followUp) <= horizon).map((v): Item => ({
      id: `f${v.id}`, icon: 'medical', tint: c.accent, title: t('Follow-up: {{a}}', { a: v.reason || v.diagnosis || t('Vet visit') }), date: new Date(v.followUp!),
      onPress: () => router.push('/visit-prep'),
    })),
    ...view.travelPlans.map((p): Item => ({ id: p.id, icon: 'airplane', tint: c.sky, title: t('Trip to {{a}}', { a: countryName(p.destination) }), date: new Date(p.arrival), onPress: () => router.push(`/travel/${p.id}`) })),
  ].sort((a, b) => a.date.getTime() - b.date.getTime()).slice(0, 6);

  return (
    <Card>
      <Row style={{ justifyContent: 'space-between' }}>
        <T variant="title">{t('Coming up')}</T>
        <IconButton icon="add" label={t('Add reminder')} tint={c.accent} bg={`${c.accent}22`} size={34} onPress={() => router.push('/reminder')} />
      </Row>
      {items.length === 0 && <T variant="sub">{t('Nothing due in the next 60 days.')}</T>}
      {items.map((it) => (
        <Row key={it.id} gap={12}>
          <Pressable onPress={it.onPress} style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 12 }} accessibilityRole="button">
            <IconBadge icon={it.icon} tint={it.tint} size={36} />
            <View style={{ flex: 1 }}>
              <T variant="headline" style={{ fontSize: 15 }} numberOfLines={1}>{it.title}</T>
              <T variant="caption" color={it.date < new Date() ? c.danger : c.ink2}>{relativeDay(it.date)}</T>
            </View>
            <T variant="caption" color={c.ink3}>{formatDate(it.date, 'short')}</T>
          </Pressable>
          {it.onDone && <IconButton icon="checkmark" label={t('Mark as done')} tint={c.sage} bg={`${c.sage}22`} size={32} onPress={it.onDone} />}
        </Row>
      ))}
    </Card>
  );
}

function WeightCard({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const entries = view.weights.slice(-8);
  const last = entries.at(-1);
  const prev = entries.at(-2);
  return (
    <Card onPress={() => router.push({ pathname: '/health', params: { section: 'weight' } })}>
      <Row style={{ justifyContent: 'space-between' }} align="flex-end">
        <View>
          <T variant="eyebrow">{t('Weight trend')}</T>
          <T variant="display" style={{ fontSize: 28 }}>{last ? formatWeight(last.kg, unit) : '—'}</T>
        </View>
        {last && prev && (
          <Row gap={4} style={{ backgroundColor: c.surfaceMuted, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 5 }}>
            <Ionicons name={last.kg >= prev.kg ? 'trending-up' : 'trending-down'} size={14} color={c.ink2} />
            <T variant="caption">{formatWeight(Math.abs(last.kg - prev.kg), unit)}</T>
          </Row>
        )}
      </Row>
      {entries.length >= 2
        ? <LineChart values={entries.map((e) => e.kg)} color={c.sage} height={70} showDots={false} />
        : <T variant="sub">{t('Log weight regularly to see the trend.')}</T>}
    </Card>
  );
}

import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Image, Pressable, View } from 'react-native';
import { LineChart, SeverityDots, StackedBars } from '@/components/extras';
import { TabPetSwitcher } from '@/components/petParts';
import { Button, Card, EmptyState, IconBadge, Pill, ProBadge, Row, SectionHeader, Segmented, T, TabScreen } from '@/components/ui';
import { addMonths, daysBetween, startOfMonth } from '@/lib/dates';
import { defaultCurrency, formatDate, formatMoney, formatWeight, resolvedUnit, weightValue } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { FREE_LIMITS, requirePremium } from '@/lib/premium';
import { type PetView, severityTrend, useSelectedPet, usePremium, vaccineStatus } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import type { ClaimStatus, ExpenseCategory } from '@/lib/types';

type Section = 'vaccines' | 'journal' | 'symptoms' | 'weight' | 'costs';

export default function Health() {
  const { t } = useTranslation();
  const params = useLocalSearchParams<{ section?: Section }>();
  const [section, setSection] = useState<Section>('vaccines');
  const view = useSelectedPet();
  useEffect(() => { if (params.section) setSection(params.section); }, [params.section]);
  if (!view.pet) return null;
  return (
    <TabScreen title={t('Health')}>
      <TabPetSwitcher />
      <Segmented value={section} onChange={setSection} options={[
        { value: 'vaccines', label: t('Vaccines') }, { value: 'journal', label: t('Vet journal') }, { value: 'symptoms', label: t('Symptoms') },
        { value: 'weight', label: t('Weight') }, { value: 'costs', label: t('Costs') },
      ]} />
      {section === 'vaccines' && <Vaccines view={view} />}
      {section === 'journal' && <Journal view={view} />}
      {section === 'symptoms' && <Symptoms view={view} />}
      {section === 'weight' && <Weight view={view} />}
      {section === 'costs' && <Costs view={view} />}
    </TabScreen>
  );
}

function Vaccines({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const statusColor = { upToDate: c.sage, dueSoon: c.butter, overdue: c.danger };
  const statusText = { upToDate: 'Up to date', dueSoon: 'Due soon', overdue: 'Overdue' };
  return (
    <>
      <SectionHeader title={t('Vaccinations')} action={t('Add')} onAction={() => router.push('/vaccine')} />
      {view.vaccinations.length === 0 && (
        <EmptyState icon="medkit-outline" title={t('No vaccines yet')} message={t('Add past vaccinations and PetTrack will remind you before the next one is due.')}
          action={t('Add vaccine')} onAction={() => router.push('/vaccine')} />
      )}
      {view.vaccinations.map((v) => {
        const s = vaccineStatus(v);
        return (
          <Card key={v.id} padding={14} onPress={() => router.push({ pathname: '/vaccine', params: { id: v.id } })}>
            <Row gap={14}>
              <IconBadge icon="medkit" tint={statusColor[s]} />
              <View style={{ flex: 1 }}>
                <T variant="headline">{v.name}</T>
                <T variant="caption">{v.nextDue ? t('Next: {{a}}', { a: formatDate(v.nextDue) }) : t('Given {{a}}', { a: formatDate(v.dateGiven) })}</T>
              </View>
              <Pill text={t(statusText[s])} tint={statusColor[s]} />
            </Row>
          </Card>
        );
      })}
    </>
  );
}

function Journal({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  return (
    <>
      <Pressable onPress={() => requirePremium('reportScanning', () => router.push('/scan'))} accessibilityRole="button" style={({ pressed }) => ({ transform: [{ scale: pressed ? 0.985 : 1 }] })}>
        <LinearGradient colors={[c.forest, c.forestDeep]} style={{ borderRadius: radius.card, padding: 16, flexDirection: 'row', gap: 14, alignItems: 'center' }}>
          <View style={{ width: 48, height: 48, borderRadius: 14, backgroundColor: '#F6F0E41F', alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="scan" size={24} color={c.cream} />
          </View>
          <View style={{ flex: 1, gap: 3 }}>
            <Row gap={6}><T variant="headline" color={c.cream}>{t('Scan a vet report')}</T>{!premium && <ProBadge />}</Row>
            <T variant="caption" color="#F6F0E4B3">{t("Photograph a report or invoice – we'll fill in the visit for you.")}</T>
          </View>
          <Ionicons name="chevron-forward" size={18} color="#F6F0E480" />
        </LinearGradient>
      </Pressable>
      <Card onPress={() => router.push('/visit-prep')}>
        <Row gap={14}>
          <IconBadge icon="clipboard" tint={c.sage} size={46} />
          <View style={{ flex: 1 }}>
            <T variant="headline">{t('Prepare for the next visit')}</T>
            <T variant="caption">{t('A one-page summary of everything since the last check-up, plus your questions.')}</T>
          </View>
          <Ionicons name="chevron-forward" size={18} color={c.ink3} />
        </Row>
      </Card>
      <SectionHeader title={t('Visits')} action={t('Add')} onAction={() => router.push('/visit-edit')} />
      {view.visits.length === 0 && <EmptyState icon="medical-outline" title={t('Your vet journal is empty')} message={t('Record check-ups, diagnoses and treatments to build a complete medical history.')} />}
      {view.visits.map((v) => (
        <Card key={v.id} padding={14} onPress={() => router.push(`/visit/${v.id}`)}>
          <Row gap={14} align="flex-start">
            <View style={{ width: 50, alignItems: 'center', backgroundColor: `${c.accent}1A`, borderRadius: 12, paddingVertical: 6 }}>
              <T variant="number" style={{ fontSize: 20 }}>{new Date(v.date).getDate()}</T>
              <T variant="caption" color={c.accent} style={{ textTransform: 'uppercase' }}>{formatDate(v.date, 'short').replace(/[\d.\s]/g, '')}</T>
            </View>
            <View style={{ flex: 1, gap: 3 }}>
              <Row gap={6}><T variant="headline" numberOfLines={1} style={{ flexShrink: 1 }}>{v.reason || v.diagnosis || t('Vet visit')}</T>{v.source === 'scan' && <Ionicons name="scan" size={14} color={c.plum} />}</Row>
              {!!v.diagnosis && v.diagnosis !== v.reason && <T variant="sub" numberOfLines={2}>{v.diagnosis}</T>}
              <T variant="caption" color={c.ink3}>{[v.clinic, v.cost !== undefined ? formatMoney(v.cost, v.currency) : ''].filter(Boolean).join(' · ')}</T>
            </View>
          </Row>
        </Card>
      ))}
    </>
  );
}

function Symptoms({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const start = () => (view.openSymptomCases.length >= FREE_LIMITS.symptomCases && !premium
    ? requirePremium('symptomDiary', () => {})
    : router.push('/symptom-edit'));
  return (
    <>
      <SectionHeader title={t('Symptom diary')} action={t('New')} onAction={start} />
      <T variant="sub">{t('Noticed a rash, lump, limp or sore eye? Take a photo each day. At the vet, show exactly how it changed – by day and time.')}</T>
      {view.symptomCases.length === 0 && (
        <EmptyState icon="camera-outline" title={t('Nothing being tracked')} message={t('Start a diary the moment you notice something unusual.')} action={t('Start a diary')} onAction={start} />
      )}
      {view.symptomCases.map((sc) => {
        const entries = view.entriesFor(sc);
        const last = entries.at(-1);
        const trend = severityTrend(entries);
        return (
          <Card key={sc.id} padding={14} onPress={() => router.push(`/symptom/${sc.id}`)}>
            <Row gap={14}>
              {last?.photo ? <Image source={{ uri: last.photo }} style={{ width: 58, height: 58, borderRadius: 15 }} /> : <IconBadge icon="camera-outline" tint={c.ink3} size={58} />}
              <View style={{ flex: 1, gap: 3 }}>
                <Row gap={6}><T variant="headline" numberOfLines={1} style={{ flexShrink: 1 }}>{sc.title}</T>{sc.resolved && <Pill text={t('Resolved')} tint={c.sage} />}</Row>
                <T variant="caption">{[sc.area, t('Day {{a}}', { a: daysBetween(sc.start, new Date()) + 1 }), t('{{a}} entries', { a: entries.length })].filter(Boolean).join(' · ')}</T>
                {trend !== undefined && <TrendLabel trend={trend} />}
              </View>
              {last && <SeverityDots value={last.severity} />}
            </Row>
          </Card>
        );
      })}
    </>
  );
}

export function TrendLabel({ trend }: { trend: number }) {
  const c = useTheme();
  const { t } = useTranslation();
  const color = trend < 0 ? c.sage : trend > 0 ? c.danger : c.ink2;
  return (
    <Row gap={4}>
      <Ionicons name={trend < 0 ? 'trending-down' : trend > 0 ? 'trending-up' : 'remove'} size={14} color={color} />
      <T variant="caption" color={color}>{t(trend < 0 ? 'Improving' : trend > 0 ? 'Getting worse' : 'No change')}</T>
    </Row>
  );
}

function Weight({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const remove = useStore((s) => s.remove);
  const [range, setRange] = useState<'3' | '6' | '12' | 'all'>('6');
  const entries = view.weights.filter((w) => range === 'all' || new Date(w.date) >= addMonths(new Date(), -Number(range)));
  return (
    <>
      <SectionHeader title={t('Weight')} action={t('Log')} onAction={() => router.push('/weight')} />
      <Row gap={10}>
        <Button style={{ flex: 1 }} small variant="soft" tint={c.sage} icon="body-outline" title={t('Body condition')} onPress={() => router.push('/portions')} />
        <Button style={{ flex: 1 }} small variant="soft" tint={c.sky} icon="swap-horizontal" title={t('kg ⇄ lb')} onPress={() => router.push('/converter')} />
      </Row>
      <Card>
        <Row align="flex-end" gap={10}>
          <T variant="display">{view.latestWeight ? formatWeight(view.latestWeight.kg, unit) : '—'}</T>
          {view.pet?.targetWeightKg !== undefined && <T variant="caption">{t('Target {{a}}', { a: formatWeight(view.pet.targetWeightKg, unit) })}</T>}
        </Row>
        <Segmented value={range} onChange={setRange} options={[{ value: '3', label: t('3M') }, { value: '6', label: t('6M') }, { value: '12', label: t('1Y') }, { value: 'all', label: t('All') }]} />
        {entries.length >= 2
          ? <LineChart values={entries.map((e) => weightValue(e.kg, unit))} color={c.sage} height={190}
              target={view.pet?.targetWeightKg !== undefined ? weightValue(view.pet.targetWeightKg, unit) : undefined} />
          : <T variant="sub">{t('Add at least two entries to see a chart.')}</T>}
      </Card>
      {view.weights.length > 0 && (
        <Card padding={16}>
          {[...view.weights].reverse().map((w) => (
            <Row key={w.id} style={{ justifyContent: 'space-between', minHeight: 40 }}>
              <T variant="sub">{formatDate(w.date)}</T>
              <Row gap={14}>
                <T variant="number">{formatWeight(w.kg, unit)}</T>
                <Pressable onPress={() => remove('weights', w.id)} accessibilityRole="button" accessibilityLabel={t('Delete')} hitSlop={8}>
                  <Ionicons name="trash-outline" size={16} color={c.ink3} />
                </Pressable>
              </Row>
            </Row>
          ))}
        </Card>
      )}
    </>
  );
}

const CAT_COLORS = (c: ReturnType<typeof useTheme>): Record<ExpenseCategory, string> => ({
  vet: c.accent, food: c.butter, medication: c.plum, insurance: c.sky, grooming: c.sage, supplies: '#9A8763', other: c.ink3,
});
export const CATEGORY_ICON: Record<ExpenseCategory, keyof typeof Ionicons.glyphMap> = {
  vet: 'medical', food: 'restaurant', medication: 'bandage', insurance: 'shield-checkmark', grooming: 'cut', supplies: 'bag-handle', other: 'ellipsis-horizontal',
};
export const CLAIM_COLORS = (c: ReturnType<typeof useTheme>): Record<ClaimStatus, string> => ({ draft: c.ink3, submitted: c.sky, approved: c.butter, paid: c.sage, denied: c.danger });

function Costs({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const currency = view.expenses[0]?.currency ?? defaultCurrency();
  const colors = CAT_COLORS(c);
  const total = (since: Date) => view.expenses.filter((e) => new Date(e.date) >= since && e.currency === currency).reduce((s, e) => s + e.amount, 0);
  const months = useMemo(() => Array.from({ length: 6 }, (_, i) => startOfMonth(addMonths(new Date(), i - 5))), []);
  const bars = months.map((m, i) => {
    const next = months[i + 1] ?? addMonths(m, 1);
    const inMonth = view.expenses.filter((e) => new Date(e.date) >= m && new Date(e.date) < next && e.currency === currency);
    const parts = (Object.keys(colors) as ExpenseCategory[]).map((k) => ({ key: k, value: inMonth.filter((e) => e.category === k).reduce((s, e) => s + e.amount, 0) })).filter((p) => p.value > 0);
    return { label: m.toLocaleDateString(undefined, { month: 'short' }), parts };
  });
  const yearStart = new Date(new Date().getFullYear(), 0, 1);
  return (
    <>
      <SectionHeader title={t('Costs')} action={t('Add')} onAction={() => router.push('/expense')} />
      <Row gap={10}>
        {[{ label: 'This month', value: total(startOfMonth(new Date())), tint: c.accent }, { label: 'This year', value: total(yearStart), tint: c.sky }].map((x) => (
          <Card key={x.label} style={{ flex: 1 }} padding={16}>
            <T variant="eyebrow">{t(x.label)}</T>
            <T variant="display" style={{ fontSize: 24 }} numberOfLines={1}>{formatMoney(x.value, currency)}</T>
            <View style={{ width: 28, height: 4, borderRadius: 2, backgroundColor: x.tint }} />
          </Card>
        ))}
      </Row>
      <Card>
        <Row style={{ justifyContent: 'space-between' }}><T variant="eyebrow">{t('Last 6 months')}</T>{!premium && <ProBadge />}</Row>
        {premium ? (
          <StackedBars data={bars} colors={colors} />
        ) : (
          <View style={{ alignItems: 'center', gap: 10, paddingVertical: 20 }}>
            <Ionicons name="bar-chart" size={34} color={c.ink3} />
            <Button variant="soft" title={t('Unlock with Premium')} onPress={() => requirePremium('costInsights', () => {})} />
          </View>
        )}
      </Card>
      {view.expenses.length === 0
        ? <EmptyState icon="card-outline" title={t('No expenses yet')} message={t('Track vet bills, food, insurance and more.')} />
        : (
          <Card padding={16}>
            {view.expenses.map((e) => (
              <Pressable key={e.id} onPress={() => router.push({ pathname: '/expense', params: { id: e.id } })} accessibilityRole="button">
                <Row gap={12} style={{ minHeight: 52 }}>
                  <IconBadge icon={CATEGORY_ICON[e.category]} tint={colors[e.category]} size={36} />
                  <View style={{ flex: 1 }}>
                    <T variant="headline" style={{ fontSize: 15 }} numberOfLines={1}>{e.title || t(e.category.charAt(0).toUpperCase() + e.category.slice(1))}</T>
                    <T variant="caption" color={c.ink3}>{formatDate(e.date)}</T>
                  </View>
                  <T variant="number">{formatMoney(e.amount, e.currency)}</T>
                </Row>
              </Pressable>
            ))}
          </Card>
        )}
      <SectionHeader title={t('Insurance claims')} action={view.visits.length ? t('New claim') : undefined} onAction={() => router.push('/claim')} />
      {view.claims.length === 0 ? (
        <Card>
          <T variant="sub">{t("Bundle the invoice, vet report and symptom diary into one PDF for your insurer, then track the claim until it's paid.")}</T>
          {view.visits.length === 0 ? <T variant="caption">{t('Add a vet visit first.')}</T>
            : <Button variant="soft" tint={c.sky} icon="document-attach-outline" title={t('Start a claim')} onPress={() => router.push('/claim')} />}
        </Card>
      ) : (
        <Card padding={16}>
          {view.claims.map((cl) => {
            const visit = view.visits.find((v) => v.id === cl.visitId);
            const tint = CLAIM_COLORS(c)[cl.status];
            return (
              <Pressable key={cl.id} onPress={() => router.push({ pathname: '/claim', params: { id: cl.id } })} accessibilityRole="button">
                <Row gap={12} style={{ minHeight: 56 }}>
                  <IconBadge icon="document-text" tint={tint} size={36} />
                  <View style={{ flex: 1 }}>
                    <T variant="headline" style={{ fontSize: 15 }} numberOfLines={1}>{visit?.reason || visit?.diagnosis || t('Vet visit')}</T>
                    <T variant="caption" color={c.ink3}>{[cl.insurer, visit ? formatDate(visit.date) : ''].filter(Boolean).join(' · ')}</T>
                  </View>
                  <View style={{ alignItems: 'flex-end', gap: 4 }}>
                    <T variant="number">{formatMoney(cl.claimed, cl.currency)}</T>
                    <Pill text={t(cl.status.charAt(0).toUpperCase() + cl.status.slice(1))} tint={tint} />
                  </View>
                </Row>
              </Pressable>
            );
          })}
        </Card>
      )}
    </>
  );
}

import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import { Image, Pressable, View } from 'react-native';
import { SEVERITY_LABELS, SeverityDots, severityColor } from '@/components/extras';
import { Button, Card, Columns, EmptyState, IconButton, Row, SectionHeader, Screen, T, useWide } from '@/components/ui';
import { daysBetween } from '@/lib/dates';
import { formatDate, formatDateTime, formatTime } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { cancelForItem, scheduleSymptom } from '@/lib/notifications';
import { shareHtmlAsPdf, symptomHtml } from '@/lib/pdf';
import { requirePremium } from '@/lib/premium';
import { severityTrend } from '@/lib/selectors';
import { getState, useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import { showPreview } from '@/lib/uiState';
import { TrendLabel } from '../(tabs)/health';

export default function SymptomDetail() {
  const c = useTheme();
  const { t } = useTranslation();
  const wide = useWide();
  const { id } = useLocalSearchParams<{ id: string }>();
  const sc = useStore((s) => s.data.symptomCases.find((x) => x.id === id));
  const pet = useStore((s) => s.data.pets.find((p) => p.id === sc?.petId));
  const all = useStore((s) => s.data.symptomEntries);
  const entries = useMemo(() => all.filter((e) => e.caseId === id).sort((a, b) => a.date.localeCompare(b.date)), [all, id]);
  const [index, setIndex] = useState<number | null>(null);
  const remove = useStore((s) => s.remove);
  if (!sc || !pet) return <Screen title=""><T>—</T></Screen>;
  const current = entries[index ?? entries.length - 1];
  const trend = severityTrend(entries);
  const first = entries[0];

  const share = () => requirePremium('symptomDiary', async () => {
    const html = await shareHtmlAsPdf(symptomHtml(pet, sc, entries), `${pet.name}-${sc.title}`);
    if (html) showPreview(html);
  });

  /** Big photo with a scrubber: step through the days like a flip-book – made for showing the vet. */
  const viewer = current && (
    <Card padding={12}>
      <View style={{ borderRadius: radius.medium, overflow: 'hidden', aspectRatio: wide ? 1 : 4 / 3, backgroundColor: c.surfaceMuted }}>
        {current.photo ? <Image source={{ uri: current.photo }} style={{ width: '100%', height: '100%' }} accessibilityLabel={formatDateTime(current.date)} />
          : <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}><Ionicons name="document-text-outline" size={40} color={c.ink3} /></View>}
        <View style={{ position: 'absolute', left: 10, top: 10, backgroundColor: '#000A', borderRadius: 999, paddingHorizontal: 10, paddingVertical: 5 }}>
          <T variant="caption" color="#fff">{t('Day {{a}}', { a: daysBetween(sc.start, current.date) + 1 })} · {formatDateTime(current.date)}</T>
        </View>
      </View>
      <Row style={{ justifyContent: 'space-between' }}>
        <IconButton icon="chevron-back" label={t('Previous')} onPress={() => setIndex(Math.max(0, (index ?? entries.length - 1) - 1))} />
        <View style={{ alignItems: 'center', gap: 4, flex: 1 }}>
          <T variant="headline" color={severityColor(c, current.severity)}>{t(SEVERITY_LABELS[current.severity])}</T>
          <SeverityDots value={current.severity} />
        </View>
        <IconButton icon="chevron-forward" label={t('Next')} onPress={() => setIndex(Math.min(entries.length - 1, (index ?? entries.length - 1) + 1))} />
      </Row>
      <Row gap={4} style={{ justifyContent: 'center', flexWrap: 'wrap' }}>
        {entries.map((e, i) => (
          <Pressable key={e.id} onPress={() => setIndex(i)} hitSlop={6} accessibilityRole="button" accessibilityLabel={formatDateTime(e.date)}>
            <View style={{ width: e === current ? 18 : 8, height: 8, borderRadius: 4, backgroundColor: e === current ? c.ink : severityColor(c, e.severity) }} />
          </Pressable>
        ))}
      </Row>
      {!!current.note && <T variant="sub" center>{current.note}</T>}
    </Card>
  );

  const timeline = (
    <>
      <SectionHeader title={t('Timeline')} />
      {entries.length === 0 && <EmptyState icon="camera-outline" title={t('No entries yet')} message={t('Add the first photo so you have a baseline to compare against.')} />}
      {[...entries].reverse().map((e) => (
        <Pressable key={e.id} onPress={() => setIndex(entries.indexOf(e))} onLongPress={() => remove('symptomEntries', e.id)} accessibilityRole="button">
          <Row gap={12} align="flex-start" style={{ paddingVertical: 6 }}>
            <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: severityColor(c, e.severity), marginTop: 6 }} />
            {e.photo && <Image source={{ uri: e.photo }} style={{ width: 64, height: 48, borderRadius: 8 }} />}
            <View style={{ flex: 1 }}>
              <Row style={{ justifyContent: 'space-between' }}>
                <T variant="headline" style={{ fontSize: 14 }}>{formatDate(e.date, 'short')}, {formatTime(e.date)}</T>
                <T variant="caption" color={severityColor(c, e.severity)}>{t(SEVERITY_LABELS[e.severity])}</T>
              </Row>
              {!!e.note && <T variant="sub">{e.note}</T>}
            </View>
          </Row>
        </Pressable>
      ))}
    </>
  );

  return (
    <Screen title="" headerRight={<Button small variant="ghost" title={t('Edit')} onPress={() => router.push({ pathname: '/symptom-edit', params: { id: sc.id } })} />}>
      <View style={{ gap: 6 }}>
        <T variant="eyebrow">{sc.area || t('Symptom diary')}</T>
        <T variant="display" style={{ fontSize: 30 }}>{sc.title}</T>
        <Row gap={10}>
          <T variant="sub">{t('Since {{a}}', { a: formatDate(sc.start) })} · {t('Day {{a}}', { a: daysBetween(sc.start, new Date()) + 1 })}</T>
          {trend !== undefined && <TrendLabel trend={trend} />}
        </Row>
      </View>
      {wide && <T variant="caption" color={c.sage}>{t('Vet mode: unfolded view with the photo history on the left and the timeline on the right.')}</T>}
      <Row gap={10}>
        {!sc.resolved && <Button style={{ flex: 1 }} tint={c.accent} icon="camera" title={t("Add today's photo")} onPress={() => router.push({ pathname: '/symptom-entry', params: { caseId: sc.id } })} />}
        <IconButton icon="share-outline" label={t('Share report')} size={54} bg={c.surfaceMuted} onPress={share} />
      </Row>
      <Columns ratio={1.2}
        left={<>
          {viewer}
          {first && current && first !== current && !wide && (
            <Row gap={10}>
              {[first, current].map((e, i) => (
                <Pressable key={e.id} style={{ flex: 1, gap: 4 }} onPress={() => setIndex(entries.indexOf(e))}>
                  {e.photo && <Image source={{ uri: e.photo }} style={{ width: '100%', aspectRatio: 1, borderRadius: 14 }} />}
                  <T variant="eyebrow">{t(i === 0 ? 'First' : 'Latest')}</T>
                  <T variant="caption">{formatDateTime(e.date)}</T>
                </Pressable>
              ))}
            </Row>
          )}
        </>}
        right={<>
          {timeline}
          {!!sc.notes && <Card><T variant="sub">{sc.notes}</T></Card>}
          <Button variant="soft" tint={c.sage} icon={sc.resolved ? 'refresh' : 'checkmark-done'} title={t(sc.resolved ? 'Reopen' : 'Mark as resolved')} onPress={() => {
            const next = { ...sc, resolved: !sc.resolved, resolvedAt: sc.resolved ? undefined : new Date().toISOString() };
            getState().upsert('symptomCases', next);
            if (next.resolved) cancelForItem(`symptom-${sc.id}`); else scheduleSymptom(next, pet.name);
          }} />
        </>}
      />
    </Screen>
  );
}

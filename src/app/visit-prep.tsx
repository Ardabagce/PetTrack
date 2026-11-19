import Ionicons from '@expo/vector-icons/Ionicons';
import { useState } from 'react';
import { Image, Pressable, View } from 'react-native';
import { Button, Columns, EditorHeader, Field, FormSection, ProBadge, Row, Screen, T } from '@/components/ui';
import { addDays, addMonths } from '@/lib/dates';
import { formatDate, formatWeight, resolvedUnit } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { shareHtmlAsPdf, visitPrepHtml } from '@/lib/pdf';
import { requirePremium } from '@/lib/premium';
import { severityTrend, useSelectedPet, usePremium, vaccineStatus } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { showPreview } from '@/lib/uiState';
import { TrendLabel } from './(tabs)/health';

/** Everything since the last vet visit on one page, plus questions to ask. */
export default function VisitPrep() {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const view = useSelectedPet();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const [question, setQuestion] = useState('');
  const pet = view.pet!;
  const since = view.lastVisit?.date ?? addMonths(new Date(), -6).toISOString();
  const startWeight = [...view.weights].reverse().find((w) => w.date <= since) ?? view.weights.find((w) => w.date >= since);
  const now = view.latestWeight;
  const change = startWeight && now ? now.kg - startWeight.kg : undefined;
  const weightText = now ? `${formatWeight(now.kg, unit)}${change !== undefined && Math.abs(change) >= 0.05 ? ` (${change > 0 ? '+' : '−'}${formatWeight(Math.abs(change), unit)})` : ''}` : '—';
  const recent = view.logs.filter((l) => l.date >= addDays(new Date(), -14).toISOString());
  const meals = (recent.filter((l) => l.kind === 'meal').length / 14).toFixed(1);
  const water = (recent.filter((l) => l.kind === 'water').length / 14).toFixed(1);
  const planned = view.slots.filter((s) => s.enabled && s.kind === 'meal').length;
  const cases = view.symptomCases.filter((sc) => view.lastUpdated(sc) >= since);
  const due = view.vaccinations.filter((v) => vaccineStatus(v) !== 'upToDate');

  const row = (icon: keyof typeof Ionicons.glyphMap, label: string, value: string, tint: string) => (
    <Row style={{ justifyContent: 'space-between', minHeight: 36 }}>
      <Row gap={10} style={{ flex: 1 }}><Ionicons name={icon} size={17} color={tint} /><T style={{ flex: 1 }}>{label}</T></Row>
      <T variant="number">{value}</T>
    </Row>
  );
  const add = () => {
    if (!question.trim()) return;
    getState().upsert('questions', { id: newId(), petId: pet.id, text: question.trim(), createdAt: new Date().toISOString(), answered: false });
    setQuestion('');
  };
  const share = () => requirePremium('passportExport', async () => {
    const html = await shareHtmlAsPdf(visitPrepHtml(view, { since, weight: weightText, meals: `${meals}${planned ? ` / ${planned}` : ''}`, water }), `${pet.name}-Visit-Summary`);
    if (html) showPreview(html);
  });

  return (
    <Screen modal>
      <EditorHeader title={t('Visit preparation')} />
      <View>
        <T variant="eyebrow">{t('Since {{a}}', { a: formatDate(since, 'long') })}</T>
        <T variant="title">{view.lastVisit ? t('Last visit: {{a}}', { a: view.lastVisit.reason || view.lastVisit.diagnosis || t('Vet visit') }) : t('No previous visit recorded')}</T>
      </View>
      <Columns
        left={<>
          <FormSection title={t('Body & appetite')}>
            {row('barbell', t('Weight'), weightText, c.sage)}
            {row('restaurant', t('Meals per day (last 14 days)'), `${meals}${planned ? ` / ${planned}` : ''}`, c.butter)}
            {row('water', t('Water refills per day'), water, c.sky)}
          </FormSection>
          <FormSection title={t('Symptoms')}>
            {cases.length === 0 && <T variant="sub">{t('No symptoms recorded since the last visit.')}</T>}
            {cases.map((sc) => {
              const entries = view.entriesFor(sc);
              const trend = severityTrend(entries);
              return (
                <Row key={sc.id} gap={12}>
                  {entries.at(-1)?.photo ? <Image source={{ uri: entries.at(-1)!.photo }} style={{ width: 44, height: 44, borderRadius: 10 }} /> : <Ionicons name="camera-outline" size={22} color={c.ink3} />}
                  <View style={{ flex: 1 }}>
                    <T variant="headline" style={{ fontSize: 15 }}>{sc.title}</T>
                    <T variant="caption">{t('{{a}} entries', { a: entries.length })}</T>
                    {trend !== undefined && <TrendLabel trend={trend} />}
                  </View>
                </Row>
              );
            })}
          </FormSection>
          {(view.activeMedications.length > 0 || due.length > 0) && (
            <FormSection title={t('Medication & vaccines')}>
              {view.activeMedications.map((m) => row('bandage', m.name, m.dosage, c.plum))}
              {due.map((v) => row('medkit', v.name, v.nextDue ? formatDate(v.nextDue) : '', vaccineStatus(v) === 'overdue' ? c.danger : c.butter))}
            </FormSection>
          )}
        </>}
        right={<>
          <FormSection title={t('Questions to ask')} footer={t("Write them down whenever they come to mind – it's easy to forget in the exam room.")}>
            {view.questions.map((q) => (
              <Row key={q.id} gap={10}>
                <Pressable onPress={() => getState().upsert('questions', { ...q, answered: true })} accessibilityRole="checkbox" accessibilityLabel={t('Mark as asked')} hitSlop={8}>
                  <Ionicons name="ellipse-outline" size={22} color={c.accent} />
                </Pressable>
                <T style={{ flex: 1 }}>{q.text}</T>
              </Row>
            ))}
            <Field value={question} onChange={setQuestion} placeholder={t('Add a question for the vet')} />
            <Button variant="soft" title={t('Add')} disabled={!question.trim()} onPress={add} />
          </FormSection>
          <Button icon="share-outline" tint={c.accent} title={t('Share summary with the vet (PDF)')} onPress={share} />
          {!premium && <Row style={{ justifyContent: 'center' }}><ProBadge /></Row>}
        </>}
      />
    </Screen>
  );
}

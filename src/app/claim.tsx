import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Banner, Button, Chip, Chips, EditorHeader, Field, FormSection, ProBadge, Row, Screen, T, ToggleRow } from '@/components/ui';
import { CURRENCIES, formatDate, parseDecimal } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { claimHtml, cap, shareHtmlAsPdf } from '@/lib/pdf';
import { requirePremium } from '@/lib/premium';
import { useSelectedPet, usePremium } from '@/lib/selectors';
import { getState, newId, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import type { Claim, ClaimStatus } from '@/lib/types';
import { showPreview } from '@/lib/uiState';

export default function ClaimEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const { id, visitId } = useLocalSearchParams<{ id?: string; visitId?: string }>();
  const { pet, visits } = useSelectedPet();
  const existing = useStore((s) => s.data.claims.find((x) => x.id === id));
  const firstVisit = visits.find((v) => v.id === visitId) ?? visits[0];
  const [cl, setCl] = useState<Claim>(existing ?? {
    id: newId(), petId: pet!.id, visitId: firstVisit?.id, insurer: pet!.insuranceProvider, policy: pet!.insurancePolicy, claimNo: '', status: 'draft',
    claimed: firstVisit?.cost ?? 0, currency: firstVisit?.currency ?? 'USD', includeSymptoms: true, notes: '', createdAt: new Date().toISOString(),
  });
  const [amount, setAmount] = useState(String(cl.claimed || ''));
  const [paid, setPaid] = useState(cl.reimbursed !== undefined ? String(cl.reimbursed) : '');
  const set = <K extends keyof Claim>(k: K, v: Claim[K]) => setCl((x) => ({ ...x, [k]: v }));
  const visit = visits.find((v) => v.id === cl.visitId);

  const persist = (): Claim => {
    const next = { ...cl, claimed: parseDecimal(amount) ?? 0, reimbursed: parseDecimal(paid), submittedAt: cl.status !== 'draft' ? cl.submittedAt ?? new Date().toISOString() : undefined };
    getState().upsert('claims', next);
    if (pet && (!pet.insuranceProvider || !pet.insurancePolicy)) getState().upsert('pets', { ...pet, insuranceProvider: pet.insuranceProvider || cl.insurer, insurancePolicy: pet.insurancePolicy || cl.policy });
    return next;
  };
  const exportPack = () => requirePremium('claimPack', async () => {
    const saved = persist();
    if (!visit || !pet) return;
    const html = await shareHtmlAsPdf(claimHtml(getState().data, pet, saved, visit), `${pet.name}-Insurance-Claim`);
    if (html) showPreview(html);
  });

  return (
    <Screen modal>
      <EditorHeader title={t(existing ? 'Edit claim' : 'New claim')} onSave={() => { persist(); router.back(); }} canSave={!!visit} />
      <FormSection title={t('Visit')}>
        <Chips>{visits.slice(0, 8).map((v) => <Chip key={v.id} label={`${formatDate(v.date, 'short')} · ${v.reason || v.diagnosis || t('Vet visit')}`} selected={cl.visitId === v.id}
          onPress={() => { set('visitId', v.id); if (!existing) { setAmount(String(v.cost ?? '')); set('currency', v.currency); } }} />)}</Chips>
        {visit && (visit.attachment
          ? <Banner icon="attach" tint={c.sage} text={t('Invoice / report photo attached')} />
          : <Banner icon="alert-circle-outline" tint={c.butter} text={t('No document photo on this visit. Scan the invoice to include it.')} />)}
        <ToggleRow label={t('Include symptom diaries')} value={cl.includeSymptoms} onChange={(v) => set('includeSymptoms', v)} />
      </FormSection>
      <FormSection title={t('Insurer')}>
        <Field label={t('Insurance company')} value={cl.insurer} onChange={(v) => set('insurer', v)} />
        <Field label={t('Policy number')} value={cl.policy} onChange={(v) => set('policy', v)} />
        <Field label={t('Claim number')} value={cl.claimNo} onChange={(v) => set('claimNo', v)} />
      </FormSection>
      <FormSection title={t('Amounts')}>
        <Field label={t('Claimed')} value={amount} onChange={setAmount} keyboard="decimal-pad" suffix={cl.currency} />
        <Chips>{CURRENCIES.slice(0, 5).map((cur) => <Chip key={cur} label={cur} selected={cl.currency === cur} onPress={() => set('currency', cur)} />)}</Chips>
        <Field label={t('Reimbursed')} value={paid} onChange={setPaid} keyboard="decimal-pad" suffix={cl.currency} placeholder={t('Optional')} />
        <T variant="caption">{t('Status')}</T>
        <Chips>{(['draft', 'submitted', 'approved', 'paid', 'denied'] as ClaimStatus[]).map((s) => <Chip key={s} label={t(cap(s))} selected={cl.status === s} onPress={() => set('status', s)} />)}</Chips>
      </FormSection>
      <Field label={t('Notes')} value={cl.notes} onChange={(v) => set('notes', v)} multiline />
      <Button icon="document-attach" tint={c.accent} title={t('Create claim pack (PDF)')} disabled={!visit} onPress={exportPack} />
      <Row style={{ justifyContent: 'center' }}>{!premium && <ProBadge />}</Row>
      <T variant="caption" center>{t('Includes the claim summary, visit details, the invoice photo and related symptom diary entries from the 30 days before the visit.')}</T>
      {existing && <Button variant="soft" tint={c.danger} title={t('Delete claim')} onPress={() => { getState().remove('claims', cl.id); router.back(); }} />}
    </Screen>
  );
}

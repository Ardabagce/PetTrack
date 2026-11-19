import Ionicons from '@expo/vector-icons/Ionicons';
import { useState } from 'react';
import { View } from 'react-native';
import { Banner, Button, Card, EditorHeader, Field, FormSection, Row, Screen, T, useConfirm } from '@/components/ui';
import { logFeeding, syncHousehold } from '@/lib/actions';
import { api, hasBackend } from '@/lib/api';
import { formatTime } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { requirePremium } from '@/lib/premium';
import { logsToday, useSelectedPet } from '@/lib/selectors';
import { getState, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { toast } from '@/lib/uiState';

/** "Who fed the dog?" – household sharing through the PetTrack server. */
export default function Family() {
  const c = useTheme();
  const { t } = useTranslation();
  const view = useSelectedPet();
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const { ask, dialog } = useConfirm();
  const household = settings.household;
  const fedToday = logsToday(view.logs).filter((l) => l.kind === 'meal');

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    try { await fn(); } catch (e) { toast((e as Error).message); } finally { setBusy(false); }
  };

  const create = () => requirePremium('familySharing', () => run(async () => {
    const res = await api<{ code: string; members: string[] }>('/api/household', { method: 'POST', body: { name: settings.memberName } });
    setSettings({ household: { role: 'owner', code: res.code, members: res.members } });
    await syncHousehold();
  }));

  const join = () => run(async () => {
    const res = await api<{ code: string; members: string[] }>('/api/household/join', { method: 'POST', body: { code: code.trim().toUpperCase(), name: settings.memberName } });
    setSettings({ household: { role: 'member', code: res.code, members: res.members } });
    const n = await syncHousehold();
    toast(t('Joined. {{a}} feedings synced.', { a: n }));
  });

  return (
    <Screen modal>
      <EditorHeader title={t('Family sharing')} />
      {dialog}
      <View style={{ gap: 10 }}>
        <Row gap={-10}>
          {[c.accent, c.sage, c.sky].map((tint, i) => (
            <View key={tint} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: tint, borderWidth: 3, borderColor: c.canvas, alignItems: 'center', justifyContent: 'center' }}>
              <Ionicons name={i === 2 ? 'paw' : 'person'} size={18} color="#fff" />
            </View>
          ))}
        </Row>
        <T variant="display" style={{ fontSize: 28 }}>{t('Who fed the dog?')}</T>
        <T variant="sub">{t('Invite your family. When anyone ticks off a meal, everyone sees it right away – with their name and the time. If someone tries to feed again, PetTrack asks first.')}</T>
      </View>

      <FormSection title={t('You')} footer={t('Shown next to everything you log, e.g. “Dinner · Alex”.')}>
        <Field label={t('Your name')} value={settings.memberName} onChange={(v) => setSettings({ memberName: v })} />
      </FormSection>

      {household.role === 'none' ? (
        hasBackend() ? (
          <>
            {!settings.memberName.trim() && <T variant="caption" color={c.accent}>{t('Enter your name first – family members see it next to each meal.')}</T>}
            <Button title={t('Create a household')} icon="home" disabled={busy || !settings.memberName.trim()} onPress={create} />
            <FormSection title={t('Have an invite code?')}>
              <Field label={t('Invite code')} value={code} onChange={setCode} placeholder="ABC-123" />
              <Button variant="soft" title={t('Join')} disabled={busy || code.trim().length < 6 || !settings.memberName.trim()} onPress={join} />
            </FormSection>
          </>
        ) : (
          <>
            <Banner icon="cloud-offline-outline" tint={c.sky} text={t('Family sharing needs the PetTrack server. Until it is connected you can try the flow with a simulated family member.')} />
            <Card>
              <T variant="headline">{t('Try it')}</T>
              <T variant="sub">{t('Pretend Sam just fed {{a}}. Then tick off the meal yourself on the Today screen – PetTrack will warn you.', { a: view.pet?.name ?? '' })}</T>
              <Button variant="soft" icon="person" title={t('Sam fed {{a}} now', { a: view.pet?.name ?? '' })} onPress={() => {
                if (!view.pet) return;
                logFeeding(view.pet, 'meal', { fedBy: 'Sam', source: 'household' });
                toast(t('Sam logged a meal'));
              }} />
            </Card>
          </>
        )
      ) : (
        <Card>
          <Row style={{ justifyContent: 'space-between' }}>
            <View><T variant="eyebrow">{t('Invite code')}</T><T variant="display" style={{ letterSpacing: 3 }}>{household.code}</T></View>
            <Ionicons name="home" size={28} color={c.sage} />
          </Row>
          <T variant="sub">{t('Share this code with family members. They enter it in PetTrack → Settings → Family.')}</T>
          <T variant="caption">{t('Members')}: {household.members.join(', ')}</T>
          <Row gap={10}>
            <Button variant="soft" title={t('Sync now')} icon="sync" disabled={busy} onPress={() => run(async () => { toast(t('{{a}} new', { a: await syncHousehold() })); })} />
            <Button variant="soft" tint={c.danger} title={t('Leave household')} onPress={() => ask({
              title: t('Leave household'), message: t('You will stop seeing feedings logged by your family. Your own records stay on this device.'),
              confirm: t('Leave'), destructive: true,
              onConfirm: () => getState().setSettings({ household: { role: 'none', members: [] } }),
            })} />
          </Row>
        </Card>
      )}

      <FormSection title={t('Fed today')}>
        {fedToday.length === 0 && <T variant="sub">{t('No meals logged yet today.')}</T>}
        {fedToday.map((l) => (
          <Row key={l.id} style={{ justifyContent: 'space-between' }}>
            <Row gap={8}><Ionicons name="restaurant" size={16} color={c.butter} /><T>{l.fedBy || t('You')}</T></Row>
            <T variant="number">{formatTime(l.date)}</T>
          </Row>
        ))}
      </FormSection>

      <FormSection title={t('What is shared')}>
        <Row align="flex-start"><Ionicons name="checkmark-circle" size={18} color={c.sage} /><T variant="sub" style={{ flex: 1 }}>{t('Shared: pets, feeding times and every meal, water refill and treat.')}</T></Row>
        <Row align="flex-start"><Ionicons name="lock-closed" size={18} color={c.ink2} /><T variant="sub" style={{ flex: 1 }}>{t('Private: health records, documents and costs stay on your devices.')}</T></Row>
      </FormSection>
    </Screen>
  );
}

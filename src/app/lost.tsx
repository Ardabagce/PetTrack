import Ionicons from '@expo/vector-icons/Ionicons';
import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { SvgXml } from 'react-native-svg';
import { Banner, Button, Card, Field, FormSection, Row, Screen, T, ToggleRow } from '@/components/ui';
import { api, hasBackend, publicProfileUrl } from '@/lib/api';
import { formatDateTime } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { lostPosterHtml, qrSvg, shareHtmlAsPdf } from '@/lib/pdf';
import { requirePremium } from '@/lib/premium';
import { useSelectedPet } from '@/lib/selectors';
import { getState, newId } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import type { LostMode, Pet } from '@/lib/types';
import { showPreview, toast } from '@/lib/uiState';

interface FinderMessage { id: string; name: string; phone: string; message: string; createdAt: string }

/** Collar QR tag → public emergency page. One switch turns it into a lost-pet alert with a printable poster. */
export default function Lost() {
  const c = useTheme();
  const { t } = useTranslation();
  const { pet } = useSelectedPet();
  const [qr, setQr] = useState('');
  const [messages, setMessages] = useState<FinderMessage[]>([]);
  const [lost, setLost] = useState<LostMode>(pet?.lost ?? { active: false, since: new Date().toISOString(), lastSeen: '', message: '', reward: '', contactPhone: '' });
  const slug = pet?.publicSlug ?? '';
  const url = publicProfileUrl(slug || 'demo');

  useEffect(() => { qrSvg(url, 220).then(setQr); }, [url]);
  useEffect(() => {
    if (pet && hasBackend() && slug) api<{ messages: FinderMessage[] }>(`/api/pets/${pet.id}/messages`).then((r) => setMessages(r.messages)).catch(() => {});
  }, [pet, slug]);
  if (!pet) return null;

  const publish = async (next: Pet) => {
    getState().upsert('pets', next);
    if (!hasBackend()) return;
    try {
      const res = await api<{ slug: string }>(`/api/pets/${next.id}/public`, {
        method: 'PUT',
        body: {
          name: next.name, species: next.species, breed: next.breed, photo: next.photo, allergies: next.allergies, conditions: next.conditions,
          emergencyNotes: next.emergencyNotes, vetClinic: next.vetClinic, vetPhone: next.vetPhone, microchip: next.microchip, lost: next.lost,
        },
      });
      if (res.slug !== next.publicSlug) getState().upsert('pets', { ...next, publicSlug: res.slug });
    } catch (e) {
      toast((e as Error).message);
    }
  };

  const createTag = () => requirePremium('lostMode', () => publish({ ...pet, publicSlug: pet.publicSlug ?? newId().slice(-8) }));
  const saveLost = (active: boolean) => requirePremium('lostMode', () => {
    const next = { ...lost, active, since: active && !pet.lost?.active ? new Date().toISOString() : lost.since };
    setLost(next);
    publish({ ...pet, lost: next });
    toast(active ? t('Lost alert is live on the collar page') : t('Marked as found. Welcome home!'));
  });
  const poster = async () => {
    const html = await shareHtmlAsPdf(await lostPosterHtml({ ...pet, lost }, url), `${pet.name}-Lost`);
    if (html) showPreview(html);
  };
  const tagSheet = async () => {
    const svg = await qrSvg(url, 160);
    const tags = Array.from({ length: 6 }, () => `<div style="border:1px dashed #999;border-radius:12px;padding:10px;text-align:center;width:46%;display:inline-block;margin:1%">${svg}<div style="font:600 16px Georgia">${pet.name}</div><div style="font:11px Arial">${t('Scan if found')}</div></div>`).join('');
    const html = await shareHtmlAsPdf(`<!doctype html><html><body style="font-family:Arial">${tags}</body></html>`, `${pet.name}-QR-tags`);
    if (html) showPreview(html);
  };

  return (
    <Screen title={t('Collar QR tag')}>
      {!hasBackend() && <Banner icon="cloud-offline-outline" tint={c.sky} text={t('Preview mode: the QR page goes live once the PetTrack server is connected.')} />}
      <Card style={{ alignItems: 'center' }}>
        <View style={{ backgroundColor: '#fff', borderRadius: radius.medium, padding: 12, opacity: slug || !hasBackend() ? 1 : 0.25 }}>
          {!!qr && <SvgXml xml={qr} width={200} height={200} />}
        </View>
        <T variant="title" center>{pet.name}</T>
        <T variant="caption" center>{url}</T>
        {!slug && hasBackend()
          ? <Button title={t('Create collar tag')} icon="qr-code" onPress={createTag} />
          : (
            <Row gap={10}>
              <Button variant="soft" icon="print-outline" title={t('Print tags')} onPress={tagSheet} />
              <Button variant="soft" tint={c.sage} icon="refresh" title={t('Update page')} onPress={() => publish(pet)} />
            </Row>
          )}
        <T variant="sub" center>{t('The page shows name, photo, allergies, medical notes and how to reach you – never your address.')}</T>
      </Card>

      <FormSection title={t('Lost pet mode')}>
        <ToggleRow label={t('{{a}} is lost', { a: pet.name })} hint={t('Turns the collar page into a lost-pet alert.')} value={lost.active} onChange={saveLost} />
        <Field label={t('Last seen')} value={lost.lastSeen} onChange={(v) => setLost({ ...lost, lastSeen: v })} placeholder={t('e.g. Riverside Park, near the north gate')} />
        <Field label={t('Message for finders')} value={lost.message} onChange={(v) => setLost({ ...lost, message: v })} multiline placeholder={t('Shy, may run away. Please call, do not chase.')} />
        <Field label={t('Reward')} value={lost.reward} onChange={(v) => setLost({ ...lost, reward: v })} placeholder={t('Optional')} />
        <Field label={t('Contact phone')} value={lost.contactPhone} onChange={(v) => setLost({ ...lost, contactPhone: v })} keyboard="phone-pad" />
        <Row gap={10}>
          <Button style={{ flex: 1 }} variant="soft" title={t('Save')} onPress={() => saveLost(lost.active)} />
          <Button style={{ flex: 1 }} variant="soft" tint={c.danger} icon="document-text-outline" title={t('Lost poster')} onPress={() => requirePremium('lostMode', poster)} />
        </Row>
      </FormSection>

      {messages.length > 0 && (
        <FormSection title={t('Messages from finders')}>
          {messages.map((m) => (
            <View key={m.id} style={{ gap: 2 }}>
              <Row gap={8}><Ionicons name="chatbubble" size={14} color={c.accent} /><T variant="headline" style={{ fontSize: 15 }}>{m.name || t('Someone')}</T><T variant="caption">{formatDateTime(m.createdAt)}</T></Row>
              <T>{m.message}</T>
              {!!m.phone && <T variant="number" color={c.accent}>{m.phone}</T>}
            </View>
          ))}
        </FormSection>
      )}
    </Screen>
  );
}

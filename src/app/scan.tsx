import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import { Banner, Button, Card, EditorHeader, Field, Row, Screen, T } from '@/components/ui';
import { api, hasBackend } from '@/lib/api';
import { deviceRegion, useTranslation } from '@/lib/i18n';
import { pickPhoto } from '@/lib/images';
import { parseReport, SAMPLE_REPORT, type ParsedReport } from '@/lib/parser';
import { useTheme } from '@/lib/theme';
import { useUI } from '@/lib/uiState';

/** Photo → text → visit record. OCR runs on the PetTrack server; parsing and review happen in the app. */
export default function Scan() {
  const c = useTheme();
  const { t } = useTranslation();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [pasted, setPasted] = useState('');

  const review = (report: ParsedReport, image?: string) => {
    useUI.setState({ scanDraft: { report, image } });
    router.replace({ pathname: '/visit-edit', params: { fromScan: '1' } });
  };

  const scan = async (source: 'camera' | 'library') => {
    setError('');
    const image = await pickPhoto(source, 1800);
    if (!image) return;
    if (!hasBackend()) { setError(t('Text recognition needs the PetTrack server. Paste the report text below or try the sample.')); return; }
    setBusy(true);
    try {
      const res = await api<{ text: string; fields?: Partial<ParsedReport> }>('/api/scan', { method: 'POST', body: { image } });
      if (!res.text.trim()) { setError(t("We couldn't find any text. Try again in good light with the whole page in view.")); return; }
      const parsed = parseReport(res.text, deviceRegion());
      review({ ...parsed, ...stripEmpty(res.fields ?? {}), rawText: res.text }, image);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen modal>
      <EditorHeader title="" />
      <View style={{ height: 160, borderRadius: 28, backgroundColor: `${c.plum}22`, alignItems: 'center', justifyContent: 'center' }}>
        <Ionicons name="scan-outline" size={110} color={c.plum} />
      </View>
      <T variant="display" style={{ fontSize: 30 }}>{t('Scan a vet report')}</T>
      <T variant="sub">{t('Works with reports, invoices and vaccination certificates in English, Spanish, German, French and Dutch.')}</T>
      {busy && <Card><Row><ActivityIndicator color={c.accent} /><T>{t('Reading your report…')}</T></Row></Card>}
      {!!error && <Banner icon="information-circle" tint={c.danger} text={error} />}
      {Platform.OS !== 'web' && <Button title={t('Scan with camera')} icon="camera" disabled={busy} onPress={() => scan('camera')} />}
      <Button title={t('Choose from Photos')} variant="soft" icon="images" disabled={busy} onPress={() => scan('library')} />
      <Field label={t('Or paste the report text')} value={pasted} onChange={setPasted} multiline />
      <Row gap={10}>
        <Button style={{ flex: 1 }} variant="soft" tint={c.sage} title={t('Use this text')} disabled={!pasted.trim()} onPress={() => review(parseReport(pasted, deviceRegion()))} />
        <Button style={{ flex: 1 }} variant="soft" tint={c.plum} title={t('Try a sample')} onPress={() => review(parseReport(SAMPLE_REPORT, 'US'))} />
      </Row>
    </Screen>
  );
}

function stripEmpty<T extends object>(o: T): Partial<T> {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== '' && v !== null && v !== undefined && !(Array.isArray(v) && !v.length))) as Partial<T>;
}

import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Image, Platform, Pressable, View } from 'react-native';
import { DateField, SEVERITY_LABELS, SeverityDots, severityColor } from '@/components/extras';
import { Button, EditorHeader, Field, FormSection, Row, Screen, T } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { pickPhoto } from '@/lib/images';
import { getState, newId, useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';

export default function SymptomEntryEditor() {
  const c = useTheme();
  const { t } = useTranslation();
  const { caseId } = useLocalSearchParams<{ caseId: string }>();
  const entries = useStore((s) => s.data.symptomEntries.filter((e) => e.caseId === caseId).sort((a, b) => a.date.localeCompare(b.date)));
  const previous = entries.at(-1);
  const [photo, setPhoto] = useState<string>();
  const [severity, setSeverity] = useState(previous?.severity ?? 2);
  const [note, setNote] = useState('');
  const [date, setDate] = useState(new Date());
  const save = () => { getState().upsert('symptomEntries', { id: newId(), caseId, date: date.toISOString(), severity, note, photo }); router.back(); };
  const take = async (src: 'camera' | 'library') => { const p = await pickPhoto(src, 1400); if (p) { setPhoto(p); setDate(new Date()); } };
  return (
    <Screen modal>
      <EditorHeader title={t('New entry')} onSave={save} canSave={!!photo || !!note.trim()} />
      <View style={{ borderRadius: radius.card, overflow: 'hidden', backgroundColor: c.surfaceMuted, aspectRatio: 4 / 3, alignItems: 'center', justifyContent: 'center' }}>
        {photo ? <Image source={{ uri: photo }} style={{ width: '100%', height: '100%' }} />
          : previous?.photo ? (
            <>
              <Image source={{ uri: previous.photo }} style={{ position: 'absolute', width: '100%', height: '100%', opacity: 0.35 }} />
              <View style={{ backgroundColor: c.surface, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 6 }}><T variant="caption" color={c.ink}>{t('Try to match the previous angle')}</T></View>
            </>
          ) : <T variant="sub">{t('Add the first photo so you have a baseline to compare against.')}</T>}
      </View>
      <Row gap={10}>
        {Platform.OS !== 'web' && <Button style={{ flex: 1 }} variant="soft" icon="camera" title={t('Camera')} onPress={() => take('camera')} />}
        <Button style={{ flex: 1 }} variant="soft" tint={c.sky} icon="images" title={t('Photos')} onPress={() => take('library')} />
      </Row>
      <FormSection title={t('How does it look?')}>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="headline" color={severityColor(c, severity)}>{t(SEVERITY_LABELS[severity])}</T>
          <SeverityDots value={severity} />
        </Row>
        <Row gap={8}>
          {[1, 2, 3, 4, 5].map((n) => (
            <Pressable key={n} onPress={() => setSeverity(n)} accessibilityRole="radio" accessibilityState={{ checked: severity === n }} accessibilityLabel={t(SEVERITY_LABELS[n])}
              style={{ flex: 1, height: 44, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: severity === n ? severityColor(c, n) : c.surfaceMuted }}>
              <T variant="headline" color={severity === n ? '#fff' : c.ink2}>{n}</T>
            </Pressable>
          ))}
        </Row>
        <DateField label={t('Date & time')} value={date} max={new Date()} mode="datetime" onChange={setDate} />
        <Field label={t('Notes (itching, size, behaviour…)')} value={note} onChange={setNote} multiline />
      </FormSection>
    </Screen>
  );
}

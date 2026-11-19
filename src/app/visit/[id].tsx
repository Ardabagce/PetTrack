import { router, useLocalSearchParams } from 'expo-router';
import { Image, View } from 'react-native';
import { Button, Card, InfoRow, Screen, T } from '@/components/ui';
import { formatDate, formatMoney } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';

export default function VisitDetail() {
  const c = useTheme();
  const { t } = useTranslation();
  const { id } = useLocalSearchParams<{ id: string }>();
  const v = useStore((s) => s.data.visits.find((x) => x.id === id));
  if (!v) return <Screen title=""><T>—</T></Screen>;
  return (
    <Screen title="" headerRight={<Button small variant="ghost" title={t('Edit')} onPress={() => router.push({ pathname: '/visit-edit', params: { id: v.id } })} />}>
      <View style={{ gap: 6 }}>
        <T variant="eyebrow">{formatDate(v.date, 'full')}</T>
        <T variant="display" style={{ fontSize: 30 }}>{v.reason || v.diagnosis || t('Vet visit')}</T>
        <T variant="sub">{[v.clinic, v.vet].filter(Boolean).join(' · ')}</T>
      </View>
      <Card>
        <InfoRow icon="chatbubble-outline" label={t('Reason')} value={v.reason} />
        <InfoRow icon="pulse-outline" label={t('Diagnosis')} value={v.diagnosis} />
        <InfoRow icon="bandage-outline" label={t('Treatment')} value={v.treatment} />
        {!!v.notes && <InfoRow icon="document-text-outline" label={t('Notes')} value={v.notes} />}
        {v.cost !== undefined && <InfoRow icon="card-outline" label={t('Cost')} value={formatMoney(v.cost, v.currency)} />}
        {v.followUp && <InfoRow icon="calendar-outline" label={t('Follow-up')} value={formatDate(v.followUp, 'long')} tint={c.accent} />}
      </Card>
      {v.attachment && <Image source={{ uri: v.attachment }} style={{ width: '100%', aspectRatio: 0.75, borderRadius: 20 }} resizeMode="contain" accessibilityLabel={t('Original report')} />}
      <Button variant="soft" tint={c.sky} icon="document-attach-outline" title={t('Start a claim')} onPress={() => router.push({ pathname: '/claim', params: { visitId: v.id } })} />
    </Screen>
  );
}

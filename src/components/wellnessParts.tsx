import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import { useTranslation } from '@/lib/i18n';
import type { PetView } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { checkinAlerts, checkinToday, healthScore } from '@/lib/wellness';
import { Button, Card, Row, T } from './ui';

function Ring({ value, size = 76, color }: { value: number; size?: number; color: string }) {
  const c = useTheme();
  const r = size / 2 - 6;
  const circ = 2 * Math.PI * r;
  return (
    <View style={{ width: size, height: size, alignItems: 'center', justifyContent: 'center' }}>
      <Svg width={size} height={size} style={{ position: 'absolute' }}>
        <Circle cx={size / 2} cy={size / 2} r={r} stroke={c.surfaceMuted} strokeWidth={8} fill="none" />
        <Circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={8} fill="none" strokeLinecap="round"
          strokeDasharray={`${(value / 100) * circ} ${circ}`} transform={`rotate(-90 ${size / 2} ${size / 2})`} />
      </Svg>
      <T variant="display" style={{ fontSize: 24, lineHeight: 28 }}>{value}</T>
    </View>
  );
}

/** PetTrack Health Score: one number, one next step. */
export function ScoreCard({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const data = useStore((s) => s.data);
  const [open, setOpen] = useState(false);
  const { score, parts } = useMemo(() => healthScore(data, view.pet!), [data, view.pet]);
  const color = score >= 80 ? c.sage : score >= 60 ? c.butter : c.accent;
  const tip = [...parts].sort((a, b) => (b.max - b.points) - (a.max - a.points)).find((p) => p.tip)?.tip;
  return (
    <Card onPress={() => setOpen(!open)} accessibilityLabel={`${t('Health score')} ${score}/100`}>
      <Row gap={16}>
        <Ring value={score} color={color} />
        <View style={{ flex: 1, gap: 4 }}>
          <T variant="eyebrow">{t('Health score')}</T>
          <T variant="headline">{t(score >= 80 ? 'Looking great' : score >= 60 ? 'Doing well' : 'Needs attention')}</T>
          {tip && <T variant="sub">{t(tip)}</T>}
        </View>
        <Ionicons name={open ? 'chevron-up' : 'chevron-down'} size={18} color={c.ink3} />
      </Row>
      {open && <T variant="caption">{t('Based only on what you log in PetTrack. Not a medical assessment.')}</T>}
      {open && parts.map((p) => (
        <View key={p.id} style={{ gap: 4 }}>
          <Row style={{ justifyContent: 'space-between' }}><T variant="caption">{t(p.label)}</T><T variant="caption">{p.points}/{p.max}</T></Row>
          <View style={{ height: 6, borderRadius: 3, backgroundColor: c.surfaceMuted }}>
            <View style={{ width: `${(p.points / p.max) * 100}%`, height: 6, borderRadius: 3, backgroundColor: color }} />
          </View>
        </View>
      ))}
    </Card>
  );
}

/** Daily check-in prompt plus pattern alerts. */
export function CheckInCard({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const all = useStore((s) => s.data.checkins);
  const mine = useMemo(() => all.filter((x) => x.petId === view.pet?.id), [all, view.pet]);
  const today = checkinToday(mine);
  const alerts = checkinAlerts(mine);
  return (
    <Card>
      <Row style={{ justifyContent: 'space-between' }}>
        <View style={{ flex: 1 }}>
          <T variant="title" style={{ fontSize: 20 }}>{t('Daily check-in')}</T>
          <T variant="caption">{today ? t('Done for today') : t('Energy, appetite and stool – 10 seconds.')}</T>
        </View>
        {today
          ? <Ionicons name="checkmark-circle" size={28} color={c.sage} accessibilityLabel={t('Done')} />
          : <Button small variant="soft" title={t('Check in')} onPress={() => router.push('/checkin')} />}
      </Row>
      {alerts.map((a) => (
        <Pressable key={a.id} onPress={() => router.push('/symptom-edit')} accessibilityRole="button"
          style={{ flexDirection: 'row', gap: 10, alignItems: 'flex-start', backgroundColor: `${a.level === 'vet' ? c.danger : c.butter}1F`, borderRadius: 14, padding: 12 }}>
          <Ionicons name={a.level === 'vet' ? 'alert-circle' : 'eye'} size={18} color={a.level === 'vet' ? c.danger : c.butter} />
          <View style={{ flex: 1 }}>
            <T style={{ fontSize: 14 }}>{t(a.text, a.values ?? {})}</T>
            <T variant="caption" color={c.accent}>{t('Start a symptom diary')} →</T>
          </View>
        </Pressable>
      ))}
    </Card>
  );
}

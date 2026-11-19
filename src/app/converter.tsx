import { useState } from 'react';
import { View } from 'react-native';
import { Card, Field, Row, Screen, T } from '@/components/ui';
import { useTranslation } from '@/lib/i18n';
import { CONVERSIONS, cToF, fToC } from '@/lib/wellness';
import { useTheme } from '@/lib/theme';
import { parseDecimal } from '@/lib/format';

const fmt = (n: number) => (Math.round(n * 100) / 100).toString();

/** Two-way unit converter: type in either box. */
function Pair({ left, right, toRight, toLeft, hint }: { left: string; right: string; toRight: (n: number) => number; toLeft: (n: number) => number; hint?: string }) {
  const [a, setA] = useState('');
  const [b, setB] = useState('');
  return (
    <Card padding={14}>
      <Row gap={10}>
        <View style={{ flex: 1 }}><Field value={a} onChange={(v) => { setA(v); const n = parseDecimal(v); setB(n === undefined ? '' : fmt(toRight(n))); }} keyboard="decimal-pad" suffix={left} placeholder="0" /></View>
        <T variant="headline">⇄</T>
        <View style={{ flex: 1 }}><Field value={b} onChange={(v) => { setB(v); const n = parseDecimal(v); setA(n === undefined ? '' : fmt(toLeft(n))); }} keyboard="decimal-pad" suffix={right} placeholder="0" /></View>
      </Row>
      {hint && <T variant="caption">{hint}</T>}
    </Card>
  );
}

export default function Converter() {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <Screen title={t('Unit converter')}>
      <T variant="sub">{t('Type in either field. Handy for US food labels and EU vet reports.')}</T>
      {CONVERSIONS.map((x) => (
        <Pair key={x.id} left={x.from} right={x.to} toRight={(n) => n * x.factor} toLeft={(n) => n / x.factor}
          hint={x.id === 'volume' ? t('1 US cup of dry food weighs about 90–120 g – check the bag.') : undefined} />
      ))}
      <Pair left="°C" right="°F" toRight={cToF} toLeft={fToC} />
      <T variant="caption" color={c.ink3} center>{t('Weights in PetTrack follow your unit setting (Settings → Weight unit).')}</T>
    </Screen>
  );
}

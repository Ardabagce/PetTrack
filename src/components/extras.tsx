import DateTimePicker from '@react-native-community/datetimepicker';
import { createElement, useState } from 'react';
import { Modal, Platform, Pressable, StyleSheet, View } from 'react-native';
import Svg, { Defs, LinearGradient, Line, Path, Rect, Stop, Circle } from 'react-native-svg';
import { formatDate, formatTime, percent } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { fonts, radius, useTheme } from '@/lib/theme';
import { Button, Row, T } from './ui';

// MARK: Date & time

/** Date / time field: native picker on iOS & Android, `<input type=date|time>` on the web. */
export function DateField({ label, value, onChange, mode = 'date', min, max }: {
  label: string; value: Date; onChange: (d: Date) => void; mode?: 'date' | 'time' | 'datetime'; min?: Date; max?: Date;
}) {
  const c = useTheme();
  const [open, setOpen] = useState(false);
  const shown = mode === 'time' ? formatTime(value) : mode === 'datetime' ? `${formatDate(value)}, ${formatTime(value)}` : formatDate(value);

  if (Platform.OS === 'web') {
    const pad = (n: number) => String(n).padStart(2, '0');
    const dateStr = `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
    const timeStr = `${pad(value.getHours())}:${pad(value.getMinutes())}`;
    const style = { font: '16px Inter, system-ui', color: c.ink, background: 'transparent', border: 'none', padding: 6, colorScheme: c.scheme };
    const input = (type: 'date' | 'time', v: string) => createElement('input', {
      type, value: v, 'aria-label': label, style,
      onChange: (e: { target: { value: string } }) => {
        const next = new Date(value);
        if (!e.target.value) return;
        if (type === 'date') { const [y, m, d] = e.target.value.split('-').map(Number); next.setFullYear(y, m - 1, d); }
        else { const [h, mi] = e.target.value.split(':').map(Number); next.setHours(h, mi); }
        onChange(next);
      },
    });
    return (
      <Row style={{ justifyContent: 'space-between', minHeight: 48 }}>
        <T>{label}</T>
        <Row gap={4}>{mode !== 'time' && input('date', dateStr)}{mode !== 'date' && input('time', timeStr)}</Row>
      </Row>
    );
  }

  return (
    <View>
      <Pressable onPress={() => setOpen(true)} accessibilityRole="button" accessibilityLabel={`${label}, ${shown}`}>
        <Row style={{ justifyContent: 'space-between', minHeight: 48 }}>
          <T>{label}</T>
          <View style={{ backgroundColor: c.surfaceMuted, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 7 }}>
            <T variant="number">{shown}</T>
          </View>
        </Row>
      </Pressable>
      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <Pressable style={{ flex: 1, backgroundColor: '#0006', justifyContent: 'flex-end' }} onPress={() => setOpen(false)}>
          <Pressable style={{ backgroundColor: c.surface, borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 16, paddingBottom: 34 }}>
            <DateTimePicker
              value={value} mode={mode} display={Platform.OS === 'ios' ? (mode === 'time' ? 'spinner' : 'inline') : 'default'}
              minimumDate={min} maximumDate={max} themeVariant={c.scheme} accentColor={c.accent}
              onChange={(_, d) => { if (d) onChange(d); if (Platform.OS === 'android') setOpen(false); }}
            />
            {Platform.OS === 'ios' && <Button title="OK" onPress={() => setOpen(false)} />}
          </Pressable>
        </Pressable>
      </Modal>
    </View>
  );
}

// MARK: Charts

export function LineChart({ values, height = 140, color, target, showDots = true }: {
  values: number[]; height?: number; color: string; target?: number; showDots?: boolean;
}) {
  const c = useTheme();
  const [width, setWidth] = useState(300);
  if (values.length < 2) return null;
  const all = target !== undefined ? [...values, target] : values;
  const min = Math.min(...all);
  const max = Math.max(...all);
  const span = max - min || 1;
  const pad = 8;
  const x = (i: number) => pad + (i / (values.length - 1)) * (width - pad * 2);
  const y = (v: number) => pad + (1 - (v - min) / span) * (height - pad * 2);
  const line = values.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const area = `${line} L${x(values.length - 1)},${height} L${x(0)},${height} Z`;
  return (
    <View onLayout={(e) => setWidth(e.nativeEvent.layout.width)} accessibilityRole="image">
      <Svg width={width} height={height}>
        <Defs>
          <LinearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor={color} stopOpacity={0.28} />
            <Stop offset="1" stopColor={color} stopOpacity={0} />
          </LinearGradient>
        </Defs>
        {[0.25, 0.5, 0.75].map((f) => <Line key={f} x1={0} x2={width} y1={height * f} y2={height * f} stroke={c.hairline} strokeWidth={0.5} />)}
        <Path d={area} fill="url(#fill)" />
        {target !== undefined && <Line x1={0} x2={width} y1={y(target)} y2={y(target)} stroke={c.accent} strokeDasharray="4 4" strokeWidth={1} />}
        <Path d={line} stroke={color} strokeWidth={2.5} fill="none" strokeLinecap="round" strokeLinejoin="round" />
        {showDots && values.map((v, i) => <Circle key={i} cx={x(i)} cy={y(v)} r={i === values.length - 1 ? 4.5 : 2.5} fill={color} />)}
      </Svg>
    </View>
  );
}

export function StackedBars({ data, height = 170, colors }: {
  data: { label: string; parts: { key: string; value: number }[] }[]; height?: number; colors: Record<string, string>;
}) {
  const c = useTheme();
  const [width, setWidth] = useState(300);
  const max = Math.max(1, ...data.map((d) => d.parts.reduce((s, p) => s + p.value, 0)));
  const slot = width / Math.max(1, data.length);
  const barW = Math.min(28, slot * 0.55);
  return (
    <View onLayout={(e) => setWidth(e.nativeEvent.layout.width)}>
      <Svg width={width} height={height}>
        {data.map((d, i) => {
          let top = height;
          return d.parts.map((p) => {
            const h = (p.value / max) * (height - 6);
            top -= h;
            return <Rect key={`${i}-${p.key}`} x={i * slot + (slot - barW) / 2} y={top} width={barW} height={Math.max(0, h - 1)} rx={4} fill={colors[p.key] ?? c.ink3} />;
          });
        })}
      </Svg>
      <Row style={{ justifyContent: 'space-around', marginTop: 6 }}>
        {data.map((d) => <T key={d.label} variant="caption" color={c.ink3}>{d.label}</T>)}
      </Row>
    </View>
  );
}

/** Two-tone bar showing today's mix of new vs. current food. */
export function MixBar({ ratio, newFood, oldFood }: { ratio: number; newFood: string; oldFood: string }) {
  const c = useTheme();
  return (
    <View style={{ gap: 8 }}>
      <View style={{ height: 14, flexDirection: 'row', gap: 3 }} accessibilityLabel={`${percent(ratio)} ${newFood}, ${percent(1 - ratio)} ${oldFood}`}>
        <View style={{ flex: ratio, backgroundColor: c.butter, borderRadius: 6 }} />
        {ratio < 1 && <View style={{ flex: 1 - ratio, backgroundColor: c.surfaceMuted, borderRadius: 6 }} />}
      </View>
      <Row style={{ justifyContent: 'space-between' }}>
        <T variant="caption">● {percent(ratio)} {newFood}</T>
        {ratio < 1 && <T variant="caption">{percent(1 - ratio)} {oldFood}</T>}
      </Row>
    </View>
  );
}

export function SeverityDots({ value }: { value: number }) {
  const c = useTheme();
  const color = severityColor(c, value);
  return (
    <Row gap={3} >
      {[1, 2, 3, 4, 5].map((i) => <View key={i} style={{ width: 14, height: 5, borderRadius: 3, backgroundColor: i <= value ? color : c.surfaceMuted }} />)}
    </Row>
  );
}

export const SEVERITY_LABELS = ['Mild', 'Mild', 'Noticeable', 'Moderate', 'Strong', 'Severe'];
export function severityColor(c: ReturnType<typeof useTheme>, v: number) {
  return v <= 1 ? c.sage : v === 2 ? '#8FA65A' : v === 3 ? c.butter : v === 4 ? c.accent : c.danger;
}

// MARK: Web PDF preview

/** On the web there is no share sheet, so documents are shown in a preview frame instead. */
export function HtmlPreview({ html, onClose }: { html: string | null; onClose: () => void }) {
  const c = useTheme();
  const { t } = useTranslation();
  if (Platform.OS !== 'web') return null;
  return (
    <Modal visible={!!html} animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: c.surfaceMuted }}>
        <Row style={{ padding: 14, justifyContent: 'space-between', backgroundColor: c.surface, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: c.hairline }}>
          <T variant="headline">{t('Preview')}</T>
          <Button title={t('Done')} variant="soft" onPress={onClose} />
        </Row>
        <T variant="caption" center style={{ padding: 8 }}>{t('On iPhone this opens the share sheet with a PDF (AirDrop, Mail, Messages).')}</T>
        <View style={{ flex: 1, margin: 12, borderRadius: radius.medium, overflow: 'hidden', backgroundColor: '#fff' }}>
          {html && createElement('iframe', { srcDoc: html, title: 'preview', style: { border: 'none', width: '100%', height: '100%', background: '#fff' } })}
        </View>
      </View>
    </Modal>
  );
}

export const fontsUsed = fonts;

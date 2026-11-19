import Ionicons from '@expo/vector-icons/Ionicons';
import { router, Stack } from 'expo-router';
import { type ComponentProps, type ReactNode, useState } from 'react';
import {
  Image, Modal, Platform, Pressable, ScrollView, StyleSheet, Switch, Text, TextInput, View,
  type StyleProp, type TextStyle, type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTranslation } from '@/lib/i18n';
import { fonts, petColors, radius, useTheme } from '@/lib/theme';
import type { Pet } from '@/lib/types';

export type IconName = ComponentProps<typeof Ionicons>['name'];

const SPECIES_ICON: Record<Pet['species'], IconName> = { dog: 'paw', cat: 'paw', rabbit: 'leaf', bird: 'egg', other: 'paw' };
export const speciesIcon = (s: Pet['species']) => SPECIES_ICON[s];

// MARK: Typography

export function T({ children, style, variant = 'body', color, numberOfLines, center }: {
  children: ReactNode; style?: StyleProp<TextStyle>; variant?: 'display' | 'title' | 'headline' | 'body' | 'sub' | 'caption' | 'eyebrow' | 'number';
  color?: string; numberOfLines?: number; center?: boolean;
}) {
  const c = useTheme();
  const styles: Record<string, TextStyle> = {
    display: { fontFamily: fonts.display, fontSize: 34, lineHeight: 40, color: c.ink },
    title: { fontFamily: fonts.display, fontSize: 22, lineHeight: 28, color: c.ink },
    headline: { fontFamily: fonts.semibold, fontSize: 16, lineHeight: 21, color: c.ink },
    body: { fontFamily: fonts.body, fontSize: 15, lineHeight: 21, color: c.ink },
    sub: { fontFamily: fonts.body, fontSize: 14, lineHeight: 19, color: c.ink2 },
    caption: { fontFamily: fonts.medium, fontSize: 12, lineHeight: 16, color: c.ink2 },
    eyebrow: { fontFamily: fonts.semibold, fontSize: 11, letterSpacing: 1.3, textTransform: 'uppercase', color: c.ink3 },
    number: { fontFamily: fonts.semibold, fontSize: 15, color: c.ink, fontVariant: ['tabular-nums'] },
  };
  const base = styles[variant];
  return (
    <Text style={[base, color ? { color } : null, center ? { textAlign: 'center' } : null, style]} numberOfLines={numberOfLines}>
      {children}
    </Text>
  );
}

// MARK: Layout

export function Screen({ children, title, scroll = true, padded = true, headerRight, modal }: {
  children: ReactNode; title?: string; scroll?: boolean; padded?: boolean; headerRight?: ReactNode; modal?: boolean;
}) {
  const c = useTheme();
  const content = <View style={[{ gap: 16 }, padded && { paddingHorizontal: 20 }, { paddingBottom: modal ? 40 : 120 }]}>{children}</View>;
  return (
    <View style={{ flex: 1, backgroundColor: c.canvas }}>
      {title !== undefined && (
        <Stack.Screen options={{ title, headerShown: true, headerRight: headerRight ? () => headerRight : undefined }} />
      )}
      {scroll ? (
        <ScrollView contentContainerStyle={{ paddingTop: 12 }} keyboardShouldPersistTaps="handled" contentInsetAdjustmentBehavior="automatic">
          {content}
        </ScrollView>
      ) : content}
    </View>
  );
}

export function TabScreen({ children, title, right }: { children: ReactNode; title: string; right?: ReactNode }) {
  const c = useTheme();
  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: c.canvas }}>
      <ScrollView contentContainerStyle={{ paddingHorizontal: 20, paddingBottom: 130, gap: 18 }} keyboardShouldPersistTaps="handled">
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 12 }}>
          <T variant="display" style={{ flex: 1 }}>{title}</T>
          {right}
        </View>
        {children}
      </ScrollView>
    </SafeAreaView>
  );
}

export function Card({ children, style, padding = 18, onPress, accessibilityLabel, tone }: {
  children: ReactNode; style?: StyleProp<ViewStyle>; padding?: number; onPress?: () => void; accessibilityLabel?: string;
  tone?: 'forest' | 'danger';
}) {
  const c = useTheme();
  const bg = tone === 'forest' ? c.forest : c.surface;
  const inner = (
    <View style={[{ backgroundColor: bg, borderRadius: radius.card, padding, borderWidth: StyleSheet.hairlineWidth, borderColor: tone === 'forest' ? 'transparent' : c.hairline, gap: 12 },
      tone === 'danger' && { borderLeftWidth: 4, borderLeftColor: c.danger },
      Platform.select({ ios: { shadowColor: '#000', shadowOpacity: 0.04, shadowRadius: 12, shadowOffset: { width: 0, height: 6 } }, default: {} }), style]}>
      {children}
    </View>
  );
  if (!onPress) return inner;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={accessibilityLabel} style={({ pressed }) => ({ transform: [{ scale: pressed ? 0.985 : 1 }] })}>
      {inner}
    </Pressable>
  );
}

export const Row = ({ children, gap = 10, style, align = 'center' }: { children: ReactNode; gap?: number; style?: StyleProp<ViewStyle>; align?: ViewStyle['alignItems'] }) =>
  <View style={[{ flexDirection: 'row', alignItems: align, gap }, style]}>{children}</View>;

export const Spacer = () => <View style={{ flex: 1 }} />;

export function SectionHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  const c = useTheme();
  return (
    <Row style={{ justifyContent: 'space-between', marginTop: 4 }}>
      <T variant="title">{title}</T>
      {action && onAction && (
        <Pressable onPress={onAction} hitSlop={10} accessibilityRole="button">
          <T variant="headline" color={c.accent} style={{ fontSize: 15 }}>{action}</T>
        </Pressable>
      )}
    </Row>
  );
}

// MARK: Controls

export function Button({ title, onPress, icon, variant = 'primary', tint, disabled, small, style }: {
  title: string; onPress: () => void; icon?: IconName; variant?: 'primary' | 'soft' | 'ghost' | 'light';
  tint?: string; disabled?: boolean; small?: boolean; style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  const color = tint ?? (variant === 'primary' ? c.ink : c.accent);
  const bg = variant === 'primary' ? color : variant === 'soft' ? `${color}22` : variant === 'light' ? c.cream : 'transparent';
  const fg = variant === 'primary' ? (tint ? '#fff' : c.canvas) : variant === 'light' ? c.forestDeep : color;
  return (
    <Pressable
      onPress={onPress} disabled={disabled} accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ disabled }}
      style={({ pressed }) => [{
        backgroundColor: bg, borderRadius: variant === 'soft' ? 999 : radius.medium, paddingVertical: small || variant === 'soft' ? 10 : 16,
        paddingHorizontal: 16, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, minHeight: 44,
        opacity: disabled ? 0.45 : pressed ? 0.85 : 1, transform: [{ scale: pressed ? 0.98 : 1 }],
      }, style]}>
      {icon && <Ionicons name={icon} size={18} color={fg} />}
      <Text style={{ color: fg, fontFamily: fonts.semibold, fontSize: variant === 'soft' || small ? 14 : 16 }}>{title}</Text>
    </Pressable>
  );
}

export function IconButton({ icon, onPress, label, tint, bg, size = 42 }: { icon: IconName; onPress: () => void; label: string; tint?: string; bg?: string; size?: number }) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityLabel={label} hitSlop={6}
      style={({ pressed }) => ({ width: size, height: size, borderRadius: size / 2, backgroundColor: bg ?? c.surface, alignItems: 'center', justifyContent: 'center',
        borderWidth: bg ? 0 : StyleSheet.hairlineWidth, borderColor: c.hairline, opacity: pressed ? 0.7 : 1 })}>
      <Ionicons name={icon} size={size * 0.45} color={tint ?? c.ink} />
    </Pressable>
  );
}

export function IconBadge({ icon, tint, size = 40 }: { icon: IconName; tint: string; size?: number }) {
  return (
    <View style={{ width: size, height: size, borderRadius: size * 0.34, backgroundColor: `${tint}22`, alignItems: 'center', justifyContent: 'center' }}>
      <Ionicons name={icon} size={size * 0.48} color={tint} />
    </View>
  );
}

export function Pill({ text, tint }: { text: string; tint: string }) {
  return (
    <View style={{ backgroundColor: `${tint}22`, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 4 }}>
      <Text style={{ color: tint, fontFamily: fonts.semibold, fontSize: 12 }}>{text}</Text>
    </View>
  );
}

export function ProBadge() {
  const c = useTheme();
  return (
    <View style={{ backgroundColor: c.gold, borderRadius: 999, paddingHorizontal: 7, paddingVertical: 2 }} accessibilityLabel="Premium">
      <Text style={{ fontSize: 10, fontFamily: fonts.bold, color: c.forestDeep, letterSpacing: 1 }}>PRO</Text>
    </View>
  );
}

export function Chip({ label, selected, onPress, icon }: { label: string; selected: boolean; onPress: () => void; icon?: IconName }) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityState={{ selected }}
      style={{ flexDirection: 'row', gap: 6, alignItems: 'center', paddingHorizontal: 14, paddingVertical: 9, borderRadius: 999, backgroundColor: selected ? c.ink : c.surfaceMuted, minHeight: 38 }}>
      {icon && <Ionicons name={icon} size={14} color={selected ? c.canvas : c.ink} />}
      <Text style={{ color: selected ? c.canvas : c.ink, fontFamily: fonts.medium, fontSize: 14 }}>{label}</Text>
    </Pressable>
  );
}

export const Chips = ({ children }: { children: ReactNode }) => <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{children}</View>;

export function Segmented<V extends string>({ value, options, onChange }: { value: V; options: { value: V; label: string }[]; onChange: (v: V) => void }) {
  const c = useTheme();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ backgroundColor: c.surfaceMuted, borderRadius: 999, padding: 4, gap: 4 }}>
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <Pressable key={o.value} onPress={() => onChange(o.value)} accessibilityRole="tab" accessibilityState={{ selected }}
            style={{ paddingHorizontal: 15, paddingVertical: 9, borderRadius: 999, backgroundColor: selected ? c.ink : 'transparent' }}>
            <Text style={{ fontFamily: fonts.semibold, fontSize: 14, color: selected ? c.canvas : c.ink2 }}>{o.label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

// MARK: Forms

export function Field({ label, value, onChange, placeholder, multiline, keyboard, suffix, autoFocus, big }: {
  label?: string; value: string; onChange: (v: string) => void; placeholder?: string; multiline?: boolean;
  keyboard?: 'default' | 'decimal-pad' | 'email-address' | 'phone-pad' | 'number-pad'; suffix?: string; autoFocus?: boolean; big?: boolean;
}) {
  const c = useTheme();
  const [focused, setFocused] = useState(false);
  return (
    <View style={{ gap: 6 }}>
      {label && <T variant="caption" color={focused ? c.ink : c.ink2}>{label}</T>}
      <Row gap={8} style={[{
        backgroundColor: c.surface, borderRadius: radius.small + 2, paddingHorizontal: 14,
        borderWidth: 1, borderColor: focused ? c.ink : c.hairline,
      },
      // Soft focus ring instead of the browser's default outline.
      Platform.OS === 'web' ? { boxShadow: focused ? `0 0 0 4px ${c.ink}14` : 'none', transitionDuration: '150ms', transitionProperty: 'border-color, box-shadow' } as ViewStyle : null]}>
        <TextInput
          value={value} onChangeText={onChange} placeholder={placeholder ?? label} placeholderTextColor={c.ink3} multiline={multiline}
          keyboardType={keyboard} autoFocus={autoFocus} accessibilityLabel={label ?? placeholder}
          autoCapitalize={keyboard === 'email-address' ? 'none' : 'sentences'}
          onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
          selectionColor={c.accent}
          style={[{ flex: 1, minWidth: 0, minHeight: multiline ? 76 : 48, paddingVertical: 12, color: c.ink, fontFamily: big ? fonts.display : fonts.body, fontSize: big ? 30 : 16, textAlignVertical: multiline ? 'top' : 'center' },
            Platform.OS === 'web' ? ({ outlineStyle: 'none', outlineWidth: 0 } as unknown as TextStyle) : null]}
        />
        {suffix && <T variant="sub">{suffix}</T>}
      </Row>
    </View>
  );
}

export function ToggleRow({ label, value, onChange, hint }: { label: string; value: boolean; onChange: (v: boolean) => void; hint?: string }) {
  const c = useTheme();
  return (
    <Row style={{ justifyContent: 'space-between', minHeight: 48 }}>
      <View style={{ flex: 1, gap: 2 }}>
        <T>{label}</T>
        {hint && <T variant="caption">{hint}</T>}
      </View>
      <Switch value={value} onValueChange={onChange} trackColor={{ true: c.sage, false: c.surfaceMuted }} accessibilityLabel={label} />
    </Row>
  );
}

export function FormSection({ title, children, footer }: { title?: string; children: ReactNode; footer?: string }) {
  const c = useTheme();
  return (
    <View style={{ gap: 8 }}>
      {title && <T variant="eyebrow">{title}</T>}
      <View style={{ backgroundColor: c.surface, borderRadius: radius.medium, padding: 14, gap: 12, borderWidth: StyleSheet.hairlineWidth, borderColor: c.hairline }}>
        {children}
      </View>
      {footer && <T variant="caption">{footer}</T>}
    </View>
  );
}

export function EmptyState({ icon, title, message, action, onAction }: { icon: IconName; title: string; message: string; action?: string; onAction?: () => void }) {
  const c = useTheme();
  return (
    <Card style={{ alignItems: 'center', paddingVertical: 26 }}>
      <IconBadge icon={icon} tint={c.ink2} size={52} />
      <T variant="title" center style={{ fontSize: 19 }}>{title}</T>
      <T variant="sub" center>{message}</T>
      {action && onAction && <Button variant="soft" title={action} onPress={onAction} />}
    </Card>
  );
}

export function InfoRow({ icon, label, value, tint }: { icon: IconName; label: string; value?: string; tint?: string }) {
  const c = useTheme();
  return (
    <Row align="flex-start" gap={12}>
      <Ionicons name={icon} size={18} color={tint ?? c.ink2} style={{ width: 22, marginTop: 2 }} />
      <View style={{ flex: 1 }}>
        <T variant="caption" color={c.ink3}>{label}</T>
        <T>{value ? value : '—'}</T>
      </View>
    </Row>
  );
}

// MARK: Pets

export function PetAvatar({ pet, size = 44 }: { pet: Pet; size?: number }) {
  const c = useTheme();
  const tint = petColors(c)[pet.colorIndex % 5];
  if (pet.photo) return <Image source={{ uri: pet.photo }} style={{ width: size, height: size, borderRadius: size / 2 }} accessibilityIgnoresInvertColors />;
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: `${tint}2E`, alignItems: 'center', justifyContent: 'center' }}>
      <Ionicons name={speciesIcon(pet.species)} size={size * 0.46} color={tint} />
    </View>
  );
}

export function PetSwitcher({ pets, selectedId, onSelect, onAdd }: { pets: Pet[]; selectedId?: string; onSelect: (id: string) => void; onAdd: () => void }) {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8, alignItems: 'center' }}>
      {pets.map((p) => {
        const selected = p.id === selectedId;
        return (
          <Pressable key={p.id} onPress={() => onSelect(p.id)} accessibilityRole="button" accessibilityState={{ selected }} accessibilityLabel={p.name}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 8, padding: 4, paddingRight: selected ? 14 : 4, borderRadius: 999,
              backgroundColor: selected ? c.surface : 'transparent', borderWidth: StyleSheet.hairlineWidth, borderColor: selected ? c.hairline : 'transparent' }}>
            <PetAvatar pet={p} size={32} />
            {selected && <T variant="headline" style={{ fontSize: 15 }}>{p.name}</T>}
          </Pressable>
        );
      })}
      <IconButton icon="add" label={t('Add pet')} onPress={onAdd} bg={c.surfaceMuted} tint={c.ink2} size={40} />
    </ScrollView>
  );
}

// MARK: Dialogs

export interface ConfirmState { title: string; message?: string; confirm: string; destructive?: boolean; onConfirm: () => void }

/** Cross-platform confirm dialog (Alert.alert does nothing on the web). */
export function ConfirmDialog({ state, onClose }: { state: ConfirmState | null; onClose: () => void }) {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <Modal visible={!!state} transparent animationType="fade" onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: '#0008', justifyContent: 'center', padding: 28 }}>
        <View style={{ backgroundColor: c.surface, borderRadius: radius.card, padding: 22, gap: 12 }} accessibilityViewIsModal>
          <T variant="title">{state?.title}</T>
          {state?.message && <T variant="sub">{state.message}</T>}
          <Row gap={10} style={{ marginTop: 6 }}>
            <Button title={t('Cancel')} variant="soft" tint={c.ink2} onPress={onClose} style={{ flex: 1 }} />
            <Button title={state?.confirm ?? ''} tint={state?.destructive ? c.danger : c.accent} onPress={() => { const s = state; onClose(); s?.onConfirm(); }} style={{ flex: 1 }} />
          </Row>
        </View>
      </View>
    </Modal>
  );
}

export function useConfirm() {
  const [state, setState] = useState<ConfirmState | null>(null);
  return { ask: setState, dialog: <ConfirmDialog state={state} onClose={() => setState(null)} /> };
}

/** Header buttons for modal editors. */
export function EditorHeader({ title, onSave, canSave = true, saveLabel }: { title: string; onSave?: () => void; canSave?: boolean; saveLabel?: string }) {
  const c = useTheme();
  const { t } = useTranslation();
  return (
    <Stack.Screen options={{
      title, headerShown: true,
      headerLeft: () => (
        <Pressable onPress={() => router.back()} hitSlop={8} accessibilityRole="button" accessibilityLabel={t('Cancel')}
          style={({ pressed }) => ({ width: 36, height: 36, borderRadius: 18, alignItems: 'center', justifyContent: 'center',
            backgroundColor: c.surfaceMuted, opacity: pressed ? 0.7 : 1, marginLeft: Platform.OS === 'web' ? 12 : 0 })}>
          <Ionicons name="close" size={20} color={c.ink2} />
        </Pressable>
      ),
      headerRight: onSave ? () => (
        <Pressable onPress={onSave} disabled={!canSave} hitSlop={8} accessibilityRole="button" accessibilityState={{ disabled: !canSave }}
          style={({ pressed }) => ({ height: 36, paddingHorizontal: 16, borderRadius: 18, flexDirection: 'row', alignItems: 'center', gap: 6,
            backgroundColor: canSave ? c.accent : c.surfaceMuted, opacity: pressed ? 0.85 : 1, transform: [{ scale: pressed ? 0.97 : 1 }],
            marginRight: Platform.OS === 'web' ? 12 : 0 })}>
          <Ionicons name="checkmark" size={17} color={canSave ? '#fff' : c.ink3} />
          <Text style={{ color: canSave ? '#fff' : c.ink3, fontFamily: fonts.semibold, fontSize: 15 }}>{saveLabel ?? t('Save')}</Text>
        </Pressable>
      ) : undefined,
    }} />
  );
}

export function Banner({ icon, text, tint }: { icon: IconName; text: string; tint: string }) {
  return (
    <Row align="flex-start" style={{ backgroundColor: `${tint}1A`, borderRadius: radius.medium, padding: 14 }}>
      <Ionicons name={icon} size={18} color={tint} />
      <T variant="sub" style={{ flex: 1 }}>{text}</T>
    </Row>
  );
}

// MARK: Adaptive layout (iPhone Duo inner screen, iPad, web)

import { useWindowDimensions } from 'react-native';

/** True on wide screens such as the unfolded iPhone Duo (7.6") — layouts switch to two columns. */
export function useWide(): boolean {
  const { width } = useWindowDimensions();
  return width >= 600;
}

/** Two columns side by side when unfolded, stacked when folded. */
export function Columns({ left, right, ratio = 1 }: { left: ReactNode; right: ReactNode; ratio?: number }) {
  const wide = useWide();
  if (!wide) return <>{left}{right}</>;
  return (
    <View style={{ flexDirection: 'row', gap: 18, alignItems: 'flex-start' }}>
      <View style={{ flex: ratio, gap: 18, minWidth: 0 }}>{left}</View>
      <View style={{ flex: 1, gap: 18, minWidth: 0 }}>{right}</View>
    </View>
  );
}

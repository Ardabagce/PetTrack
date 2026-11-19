import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, ScrollView, View } from 'react-native';
import { kindColor, kindIcon } from '@/components/petParts';
import { IconBadge, PetAvatar, ProBadge, Row, T, useConfirm } from '@/components/ui';
import { conflictMessage, logFeeding } from '@/lib/actions';
import { useTranslation } from '@/lib/i18n';
import { FREE_LIMITS, requirePremium } from '@/lib/premium';
import { recentConflict, useSelectedPet, usePremium } from '@/lib/selectors';
import { radius, useTheme } from '@/lib/theme';
import { toast } from '@/lib/uiState';
import type { FeedingKind } from '@/lib/types';

export default function QuickAdd() {
  const c = useTheme();
  const { t } = useTranslation();
  const view = useSelectedPet();
  const premium = usePremium();
  const { ask, dialog } = useConfirm();
  const pet = view.pet;
  if (!pet) return null;

  const log = (kind: FeedingKind) => {
    const label = t(kind === 'meal' ? 'Meal' : kind === 'water' ? 'Water' : 'Treat');
    const commit = () => { logFeeding(pet, kind); toast(t('{{a}} logged for {{b}}', { a: label, b: pet.name })); router.back(); };
    const conflict = recentConflict(view.logs, kind);
    if (conflict) ask({ title: t('Already fed?'), message: conflictMessage(conflict, pet.name), confirm: t('Log anyway'), onConfirm: commit });
    else commit();
  };

  const go = (path: string) => { router.back(); setTimeout(() => router.push(path as never), 250); };
  const actions: { label: string; icon: keyof typeof Ionicons.glyphMap; tint: string; pro?: boolean; run: () => void }[] = [
    { label: 'Check-in', icon: 'happy', tint: c.sage, run: () => go('/checkin') },
    { label: 'Weight', icon: 'barbell', tint: c.sage, run: () => go('/weight') },
    { label: 'Vet visit', icon: 'medical', tint: c.accent, run: () => go('/visit-edit') },
    { label: 'Scan report', icon: 'scan', tint: c.plum, pro: true, run: () => { router.back(); requirePremium('reportScanning', () => setTimeout(() => router.push('/scan'), 250)); } },
    { label: 'Symptom photo', icon: 'camera', tint: c.danger, run: () => go(view.openSymptomCases[0] ? `/symptom-entry?caseId=${view.openSymptomCases[0].id}` : '/symptom-edit') },
    { label: 'Vaccine', icon: 'medkit', tint: c.sky, run: () => go('/vaccine') },
    { label: 'Expense', icon: 'card', tint: c.butter, run: () => go('/expense') },
    { label: 'Reminder', icon: 'notifications', tint: c.accent, run: () => (view.reminders.length >= FREE_LIMITS.openReminders && !premium
      ? (router.back(), requirePremium('unlimitedReminders', () => {})) : go('/reminder')) },
    { label: 'Is it safe?', icon: 'warning', tint: c.danger, run: () => go('/food-safety') },
    { label: 'Question for vet', icon: 'help-circle', tint: c.sage, run: () => go('/visit-prep') },
    { label: 'Converter', icon: 'swap-horizontal', tint: c.sky, run: () => go('/converter') },
    { label: 'SOS', icon: 'medkit', tint: c.danger, run: () => go('/sos') },
  ];

  return (
    <ScrollView keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets keyboardDismissMode="interactive" style={{ backgroundColor: c.canvas }} contentContainerStyle={{ padding: 22, gap: 18 }}>
      {dialog}
      <Row style={{ justifyContent: 'space-between' }}>
        <View><T variant="eyebrow">{t('Quick add')}</T><T variant="display" style={{ fontSize: 26 }}>{pet.name}</T></View>
        <PetAvatar pet={pet} size={42} />
      </Row>
      <Row gap={10}>
        {(['meal', 'water', 'treat'] as const).map((kind) => (
          <Pressable key={kind} onPress={() => log(kind)} accessibilityRole="button"
            style={({ pressed }) => ({ flex: 1, alignItems: 'center', gap: 6, paddingVertical: 16, borderRadius: radius.medium, backgroundColor: `${kindColor(c, kind)}22`, transform: [{ scale: pressed ? 0.96 : 1 }] })}>
            <Ionicons name={kindIcon[kind]} size={22} color={kindColor(c, kind)} />
            <T variant="headline" color={kindColor(c, kind)} style={{ fontSize: 14 }}>{t(kind === 'meal' ? 'Meal' : kind === 'water' ? 'Water' : 'Treat')}</T>
          </Pressable>
        ))}
      </Row>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>
        {actions.map((a) => (
          <Pressable key={a.label} onPress={a.run} accessibilityRole="button" accessibilityLabel={t(a.label)}
            style={({ pressed }) => ({ width: '31%', flexGrow: 1, alignItems: 'center', gap: 10, paddingVertical: 16, borderRadius: radius.medium, backgroundColor: c.surface, transform: [{ scale: pressed ? 0.96 : 1 }] })}>
            <IconBadge icon={a.icon} tint={a.tint} size={42} />
            <Row gap={4}><T variant="caption" color={c.ink} numberOfLines={1} style={{ fontSize: 13 }}>{t(a.label)}</T>{a.pro && !premium && <ProBadge />}</Row>
          </Pressable>
        ))}
      </View>
    </ScrollView>
  );
}

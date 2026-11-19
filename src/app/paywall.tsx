import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Linking, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, ProBadge, Row, T } from '@/components/ui';
import { percent } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { type Feature, FEATURES, PLANS, purchase, restorePurchases, usePurchaseState, yearlySavings } from '@/lib/premium';
import { useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import { toast } from '@/lib/uiState';

export const LINKS = { terms: 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/', privacy: 'https://pettrack.app/privacy' };

export default function Paywall() {
  const c = useTheme();
  const { t } = useTranslation();
  const { feature } = useLocalSearchParams<{ feature?: Feature }>();
  const [plan, setPlan] = useState<'yearly' | 'monthly'>('yearly');
  const busy = usePurchaseState((s) => s.busy);
  const trialAvailable = !useStore((s) => s.settings.premium.trialUsed);
  const list = [...FEATURES].sort((a, b) => (a.id === feature ? -1 : b.id === feature ? 1 : 0));
  const selected = PLANS.find((p) => p.id === plan)!;
  const period = t(plan === 'yearly' ? 'year' : 'month');

  const buy = async () => {
    if (await purchase(plan)) {
      toast(t('Welcome to Premium'));
      router.back();
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: c.forestDeep }}>
      <View style={{ position: 'absolute', right: -100, top: -120, width: 360, height: 360, borderRadius: 180, backgroundColor: '#CF5F3B', opacity: 0.35 }} />
      <SafeAreaView style={{ flex: 1 }}>
        <Row style={{ justifyContent: 'flex-end', paddingHorizontal: 18 }}>
          <Pressable onPress={() => router.back()} accessibilityRole="button" accessibilityLabel={t('Close')} hitSlop={10}
            style={{ width: 34, height: 34, borderRadius: 17, backgroundColor: '#F6F0E41F', alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="close" size={18} color={c.cream} />
          </Pressable>
        </Row>
        <ScrollView contentContainerStyle={{ padding: 24, gap: 22 }}>
          <View style={{ gap: 12 }}>
            <View style={{ alignSelf: 'flex-start' }}><ProBadge /></View>
            <T variant="display" color={c.cream} style={{ fontSize: 32 }}>{t("Everything your pet's health needs, in one place.")}</T>
            <T color="#F6F0E4B3">{t('Try PetTrack Premium free for 3 days. Cancel anytime.')}</T>
          </View>
          <View style={{ gap: 16 }}>
            {list.map((f) => (
              <Row key={f.id} gap={14} align="flex-start">
                <View style={{ width: 38, height: 38, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: f.id === feature ? c.gold : '#F6F0E41A' }}>
                  <Ionicons name={f.icon} size={18} color={f.id === feature ? c.forestDeep : c.cream} />
                </View>
                <View style={{ flex: 1 }}>
                  <T variant="headline" color={c.cream}>{t(f.title)}</T>
                  <T variant="sub" color="#F6F0E4A6">{t(f.subtitle)}</T>
                </View>
              </Row>
            ))}
          </View>
          <Row gap={10} style={{ backgroundColor: '#F6F0E414', borderRadius: radius.medium, padding: 14 }} align="flex-start">
            <Ionicons name="lock-open" size={18} color={c.gold} />
            <T variant="sub" color={c.cream} style={{ flex: 1 }}>{t('Our promise: your records are never locked. Everything you enter stays viewable and exportable for free, even if you cancel.')}</T>
          </Row>
          {PLANS.map((p) => {
            const isSel = p.id === plan;
            return (
              <Pressable key={p.id} onPress={() => setPlan(p.id)} accessibilityRole="radio" accessibilityState={{ checked: isSel }}
                style={{ flexDirection: 'row', alignItems: 'center', gap: 14, padding: 16, borderRadius: radius.medium, borderWidth: isSel ? 1.5 : 0.5,
                  borderColor: isSel ? c.gold : '#F6F0E433', backgroundColor: isSel ? '#F6F0E41F' : '#F6F0E40D' }}>
                <Ionicons name={isSel ? 'checkmark-circle' : 'ellipse-outline'} size={22} color={isSel ? c.gold : '#F6F0E466'} />
                <View style={{ flex: 1, gap: 2 }}>
                  <Row gap={8}>
                    <T variant="headline" color={c.cream}>{t(p.id === 'yearly' ? 'Yearly' : 'Monthly')}</T>
                    {p.id === 'yearly' && <View style={{ backgroundColor: c.gold, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 2 }}>
                      <T variant="caption" color={c.forestDeep} style={{ fontSize: 11 }}>{t('Save {{a}}', { a: percent(yearlySavings()) })}</T></View>}
                  </Row>
                  {trialAvailable && <T variant="caption" color="#F6F0E4A6">{t('{{a}} free trial', { a: t('3 days') })}</T>}
                </View>
                <View style={{ alignItems: 'flex-end' }}>
                  <T variant="number" color={c.cream} style={{ fontSize: 17 }}>{p.display}</T>
                  <T variant="caption" color="#F6F0E48C">{p.perMonth ? t('{{a}} / mo', { a: p.perMonth }) : t('per month')}</T>
                </View>
              </Pressable>
            );
          })}
          <Button variant="light" disabled={busy} title={busy ? '…' : t(trialAvailable ? 'Start free trial' : 'Continue')} onPress={buy} />
          <T variant="caption" color="#F6F0E48C" center>
            {trialAvailable
              ? t('{{a}} free, then {{b}} per {{c}}. Renews automatically until cancelled in Settings at least 24 hours before the end of the period.', { a: t('3 days'), b: selected.display, c: period })
              : t('{{a}} per {{b}}. Renews automatically until cancelled in Settings at least 24 hours before the end of the period.', { a: selected.display, b: period })}
          </T>
          <T variant="caption" color="#F6F0E48C" center>{t('Payment is charged to your Apple ID at confirmation of purchase. Manage or cancel any time in your App Store account settings.')}</T>
          <Row gap={18} style={{ justifyContent: 'center' }}>
            <Pressable onPress={async () => { toast(t((await restorePurchases()) ? 'Purchases restored' : 'No purchases found')); }} accessibilityRole="button"><T variant="caption" color={c.cream}>{t('Restore purchases')}</T></Pressable>
            <Pressable onPress={() => Linking.openURL(LINKS.terms)} accessibilityRole="link"><T variant="caption" color={c.cream}>{t('Terms')}</T></Pressable>
            <Pressable onPress={() => Linking.openURL(LINKS.privacy)} accessibilityRole="link"><T variant="caption" color={c.cream}>{t('Privacy')}</T></Pressable>
          </Row>
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

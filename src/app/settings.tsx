import Ionicons from '@expo/vector-icons/Ionicons';
import * as Clipboard from 'expo-clipboard';
import { router } from 'expo-router';
import { Linking, Platform, Pressable, View } from 'react-native';
import * as Sharing from 'expo-sharing';
import { File, Paths } from 'expo-file-system';
import { Chip, Chips, EditorHeader, FormSection, ProBadge, Row, Screen, T, ToggleRow, useConfirm } from '@/components/ui';
import { hasBackend } from '@/lib/api';
import { formatDate } from '@/lib/format';
import i18n, { deviceLanguage, LANGUAGES, useTranslation } from '@/lib/i18n';
import { setSimulatedPremium } from '@/lib/premium';
import { loadDemoData } from '@/lib/sample';
import { usePremium } from '@/lib/selectors';
import { getState, useStore } from '@/lib/store';
import { useTheme } from '@/lib/theme';
import { toast } from '@/lib/uiState';
import { LINKS } from './paywall';

function NavRow({ icon, label, onPress, right }: { icon: keyof typeof Ionicons.glyphMap; label: string; onPress: () => void; right?: React.ReactNode }) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} accessibilityRole="button" style={{ flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 44 }}>
      <Ionicons name={icon} size={20} color={c.accent} />
      <T style={{ flex: 1 }}>{label}</T>
      {right}
      <Ionicons name="chevron-forward" size={16} color={c.ink3} />
    </Pressable>
  );
}

export default function Settings() {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const settings = useStore((s) => s.settings);
  const setSettings = useStore((s) => s.setSettings);
  const { ask, dialog } = useConfirm();

  const exportData = async () => {
    const json = JSON.stringify({ app: 'PetTrack', exportedAt: new Date().toISOString(), data: getState().data }, null, 2);
    if (Platform.OS === 'web') {
      await Clipboard.setStringAsync(json);
      toast(t('All data copied as JSON'));
      return;
    }
    const file = new File(Paths.cache, `PetTrack-export-${new Date().toISOString().slice(0, 10)}.json`);
    file.create({ overwrite: true });
    file.write(json);
    await Sharing.shareAsync(file.uri, { mimeType: 'application/json', dialogTitle: 'PetTrack' });
  };

  return (
    <Screen modal>
      <EditorHeader title={t('Settings')} />
      {dialog}
      <FormSection>
        {premium ? (
          <Row gap={12}>
            <Ionicons name="checkmark-circle" size={28} color={c.sage} />
            <View style={{ flex: 1 }}>
              <T variant="headline">PetTrack Premium</T>
              <T variant="caption">{settings.premium.trialEndsAt && !settings.premium.plan
                ? t('Free trial until {{a}}', { a: formatDate(settings.premium.trialEndsAt) }) : t('All features unlocked')}</T>
            </View>
          </Row>
        ) : (
          <NavRow icon="sparkles" label={t('Upgrade to Premium')} onPress={() => router.push('/paywall')} right={<ProBadge />} />
        )}
      </FormSection>

      <FormSection title={t('Family')}>
        <NavRow icon="people" label={t('Family sharing')} onPress={() => router.push('/family')}
          right={settings.household.role !== 'none' ? <T variant="caption">{settings.household.members.length || 1}</T> : undefined} />
      </FormSection>

      <FormSection title={t('Preferences')}>
        <T variant="caption">{t('Language')}</T>
        <Chips>
          {LANGUAGES.map((l) => (
            <Chip key={l.code} label={l.name} selected={(settings.language ?? deviceLanguage()) === l.code}
              onPress={() => { setSettings({ language: l.code }); i18n.changeLanguage(l.code); }} />
          ))}
        </Chips>
        <T variant="caption">{t('Weight unit')}</T>
        <Chips>
          {(['auto', 'kg', 'lb'] as const).map((u) => (
            <Chip key={u} label={u === 'auto' ? t('Automatic') : u === 'kg' ? t('Kilograms') : t('Pounds')} selected={settings.weightUnit === u} onPress={() => setSettings({ weightUnit: u })} />
          ))}
        </Chips>
      </FormSection>

      <FormSection title={t('Your data')} footer={t('Our promise: your records are never locked. Everything you enter stays viewable and exportable for free, even if you cancel.')}>
        <NavRow icon="download-outline" label={t('Export all data (JSON)')} onPress={exportData} />
      </FormSection>

      <FormSection title={t('Guide')}>
        <NavRow icon="map-outline" label={t('Show the tour')} onPress={() => router.push('/tour')} />
      </FormSection>

      <FormSection title={t('About')}>
        <NavRow icon="mail-outline" label={t('Contact support')} onPress={() => Linking.openURL('mailto:support@pettrack.app')} />
        <NavRow icon="lock-closed-outline" label={t('Privacy policy')} onPress={() => Linking.openURL(LINKS.privacy)} />
        <NavRow icon="document-outline" label={t('Terms of use')} onPress={() => Linking.openURL(LINKS.terms)} />
        <Row style={{ justifyContent: 'space-between' }}><T variant="sub">{t('Server')}</T><T variant="caption">{hasBackend() ? t('Connected') : t('Offline mode')}</T></Row>
      </FormSection>

      <FormSection title={t('Testing')} footer={t('Only for testing before the App Store release.')}>
        <ToggleRow label={t('Simulate Premium')} value={premium} onChange={setSimulatedPremium} />
        <NavRow icon="flask-outline" label={t('Load demo data')} onPress={() => ask({
          title: t('Load demo data'), message: t('This replaces everything in the app with two example pets.'), confirm: t('Load'), destructive: true,
          onConfirm: () => { loadDemoData(); router.back(); },
        })} />
        <NavRow icon="trash-outline" label={t('Delete all data')} onPress={() => ask({
          title: t('Delete all data'), message: t('This removes all pets and records from this device.'), confirm: t('Delete'), destructive: true,
          onConfirm: () => { getState().replaceAll({} as never); setSettings({ tourDone: false, selectedPetId: undefined }); router.dismissAll(); router.replace('/onboarding'); },
        })} />
      </FormSection>
    </Screen>
  );
}

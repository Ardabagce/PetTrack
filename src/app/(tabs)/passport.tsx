import Ionicons from '@expo/vector-icons/Ionicons';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Linking, Platform, View } from 'react-native';
import { TabPetSwitcher } from '@/components/petParts';
import { Button, Card, Columns, IconBadge, IconButton, InfoRow, PetAvatar, ProBadge, Row, SectionHeader, T, TabScreen } from '@/components/ui';
import { stepState, destination, petFacts, travelSteps } from '@/lib/travel';
import { countryName, formatDate, relativeDay, resolvedUnit } from '@/lib/format';
import { useTranslation } from '@/lib/i18n';
import { cap, passportHtml, shareHtmlAsPdf } from '@/lib/pdf';
import { requirePremium } from '@/lib/premium';
import { type PetView, useSelectedPet, usePremium } from '@/lib/selectors';
import { useStore } from '@/lib/store';
import { radius, useTheme } from '@/lib/theme';
import { showPreview } from '@/lib/uiState';

export default function Passport() {
  const { t } = useTranslation();
  const view = useSelectedPet();
  if (!view.pet) return null;
  return (
    <TabScreen title={t('Passport')} right={<IconButton icon="settings-outline" label={t('Settings')} onPress={() => router.push('/settings')} />}>
      <TabPetSwitcher />
      <Columns
        left={<>
          <IDCard view={view} />
          <Share view={view} />
          <Emergency view={view} />
        </>}
        right={<>
          <CollarTag view={view} />
          <Travel view={view} />
          <Vet view={view} />
        </>}
      />
    </TabScreen>
  );
}

function IDCard({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const pet = view.pet!;
  const field = (label: string, value: string) => (
    <View style={{ minWidth: '45%', gap: 2 }}>
      <T variant="eyebrow" color="#F6F0E480" style={{ fontSize: 9 }}>{t(label)}</T>
      <T color={c.cream} numberOfLines={1} style={{ fontSize: 14 }}>{value || '—'}</T>
    </View>
  );
  return (
    <View style={{ borderRadius: radius.card + 4, overflow: 'hidden' }} accessible accessibilityLabel={`${t('HEALTH PASSPORT')} ${pet.name}`}>
      <LinearGradient colors={[c.forest, c.forestDeep]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ padding: 22, gap: 16 }}>
        {[0, 1, 2, 3, 4].map((i) => (
          <View key={i} style={{ position: 'absolute', right: -70 - i * 22, top: -90 - i * 22, width: 200 + i * 44, height: 200 + i * 44, borderRadius: 200, borderWidth: 1, borderColor: '#F6F0E40D' }} />
        ))}
        <Row style={{ justifyContent: 'space-between' }} align="flex-start">
          <View>
            <T variant="eyebrow" color="#F6F0E499" style={{ letterSpacing: 2 }}>{t('HEALTH PASSPORT')}</T>
            <T variant="display" color={c.cream} style={{ fontSize: 32 }}>{pet.name}</T>
          </View>
          <Button small variant="soft" tint={c.cream} title={t('Edit')} onPress={() => router.push({ pathname: '/pet-edit', params: { id: pet.id } })} />
        </Row>
        <Row gap={16}>
          <PetAvatar pet={pet} size={84} />
          <View style={{ flex: 1, flexDirection: 'row', flexWrap: 'wrap', rowGap: 8, columnGap: 10 }}>
            {field('Species', t(cap(pet.species)))}
            {field('Sex', t(cap(pet.sex)))}
            {field('Born', pet.birthDate ? formatDate(pet.birthDate) : '')}
            {field('Breed', pet.breed)}
          </View>
        </Row>
        <View>
          <T variant="eyebrow" color="#F6F0E480" style={{ fontSize: 9 }}>{t('MICROCHIP')}</T>
          <T color={c.cream} style={{ fontFamily: Platform.select({ ios: 'Menlo', default: 'monospace' }), fontSize: 17 }}>{pet.microchip || '—'}</T>
        </View>
      </LinearGradient>
    </View>
  );
}

function Share({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const unit = resolvedUnit(useStore((s) => s.settings.weightUnit));
  const pet = view.pet!;
  const share = async () => {
    const html = await shareHtmlAsPdf(passportHtml(view, unit), `${pet.name}-Health-Passport`);
    if (html) showPreview(html);
  };
  return (
    <Card>
      <Row align="flex-start" style={{ justifyContent: 'space-between' }}>
        <View style={{ flex: 1, gap: 4 }}>
          <T variant="title" style={{ fontSize: 20 }}>{t('Share with your vet')}</T>
          <T variant="caption">{t('A complete PDF health passport: vaccines, visits, weight, medication and emergency details.')}</T>
        </View>
        {!premium && <ProBadge />}
      </Row>
      <Row gap={10}>
        <Button title={t('Share passport')} icon="share-outline" tint={c.accent} style={{ flex: 1 }} onPress={() => requirePremium('passportExport', share)} />
        {!!pet.vetPhone && <IconButton icon="call" label={t('Call vet')} tint={c.sage} bg={`${c.sage}22`} size={54} onPress={() => Linking.openURL(`tel:${pet.vetPhone.replace(/[^\d+]/g, '')}`)} />}
      </Row>
      {!premium && <Button variant="ghost" small title={t('Preview passport')} onPress={() => showPreview(passportHtml(view, unit))} />}
    </Card>
  );
}

function Emergency({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const pet = view.pet!;
  return (
    <Card tone="danger">
      <Row><Ionicons name="medical" size={18} color={c.danger} /><T variant="title" style={{ fontSize: 20 }}>{t('Emergency card')}</T></Row>
      <InfoRow icon="alert-circle-outline" label={t('Allergies')} value={pet.allergies} tint={c.danger} />
      <InfoRow icon="pulse-outline" label={t('Conditions')} value={pet.conditions} tint={c.danger} />
      <InfoRow icon="bandage-outline" label={t('Current medication')} value={view.activeMedications.map((m) => [m.name, m.dosage].filter(Boolean).join(' ')).join(', ')} tint={c.danger} />
      {!!pet.bloodType && <InfoRow icon="water-outline" label={t('Blood type')} value={pet.bloodType} tint={c.danger} />}
      {!!pet.emergencyNotes && <InfoRow icon="chatbox-ellipses-outline" label={t('Notes')} value={pet.emergencyNotes} tint={c.danger} />}
      <Button small tint={c.danger} icon="medkit" title={t('Emergency help')} onPress={() => router.push('/sos')} />
    </Card>
  );
}

function CollarTag({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const pet = view.pet!;
  const lost = pet.lost?.active;
  return (
    <Card onPress={() => router.push('/lost')}>
      <Row gap={14}>
        <IconBadge icon={lost ? 'alert-circle' : 'qr-code'} tint={lost ? c.danger : c.ink} size={46} />
        <View style={{ flex: 1, gap: 3 }}>
          <Row gap={6}><T variant="headline">{lost ? t('{{a}} is marked as lost', { a: pet.name }) : t('Collar QR tag')}</T>{!premium && !lost && <ProBadge />}</Row>
          <T variant="caption">{lost ? t('Update the alert, print a poster or mark as found.') : t('Anyone who finds your pet scans the tag and sees how to reach you. One tap turns it into a lost-pet alert.')}</T>
        </View>
        <Ionicons name="chevron-forward" size={18} color={c.ink3} />
      </Row>
    </Card>
  );
}

function Travel({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const premium = usePremium();
  const data = useStore((s) => s.data);
  return (
    <Card>
      <Row style={{ justifyContent: 'space-between' }}><T variant="title" style={{ fontSize: 20 }}>{t('Travel')}</T>{!premium && <ProBadge />}</Row>
      {view.travelPlans.length === 0 && <T variant="sub">{t('Flying between the US and Europe? Get every vaccine, certificate and deadline for your destination, with countdown reminders.')}</T>}
      {view.travelPlans.map((plan) => {
        const dest = destination(plan.destination);
        const steps = travelSteps(dest, new Date(plan.arrival), petFacts(view.pet!, data.vaccinations));
        const done = steps.filter((s) => stepState(s, plan.done.includes(s.id)) === 'done').length;
        const overdue = steps.some((s) => stepState(s, plan.done.includes(s.id)) === 'overdue');
        return (
          <Card key={plan.id} padding={12} onPress={() => router.push(`/travel/${plan.id}`)} style={{ backgroundColor: c.surfaceMuted }}>
            <Row gap={12}>
              <T style={{ fontSize: 30 }}>{dest.flag}</T>
              <View style={{ flex: 1 }}>
                <T variant="headline">{countryName(dest.code)}</T>
                <T variant="caption">{formatDate(plan.arrival)} · {relativeDay(plan.arrival)}</T>
              </View>
              <T variant="number" color={overdue ? c.danger : c.ink}>{done}/{steps.length}</T>
            </Row>
          </Card>
        );
      })}
      <Button variant="soft" tint={c.sky} icon="airplane-outline" title={t('Plan a trip')} onPress={() => requirePremium('travelPlanner', () => router.push('/travel-edit'))} />
    </Card>
  );
}

function Vet({ view }: { view: PetView }) {
  const c = useTheme();
  const { t } = useTranslation();
  const pet = view.pet!;
  return (
    <>
      <SectionHeader title={t('Veterinarian')} />
      <Card>
        <InfoRow icon="business-outline" label={t('Clinic')} value={pet.vetClinic} tint={c.accent} />
        <InfoRow icon="person-outline" label={t('Veterinarian')} value={pet.vetName} tint={c.accent} />
        <InfoRow icon="call-outline" label={t('Phone')} value={pet.vetPhone} tint={c.accent} />
        <InfoRow icon="mail-outline" label={t('Email')} value={pet.vetEmail} tint={c.accent} />
        {(!!pet.insuranceProvider || !!pet.insurancePolicy) && (
          <InfoRow icon="shield-checkmark-outline" label={t('Insurance')} value={[pet.insuranceProvider, pet.insurancePolicy].filter(Boolean).join(' · ')} tint={c.sky} />
        )}
      </Card>
    </>
  );
}

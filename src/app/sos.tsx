import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Linking, Modal, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, Card, Row, T } from '@/components/ui';
import { hotlines } from '@/lib/foodSafety';
import { deviceRegion, useTranslation } from '@/lib/i18n';
import { useSelectedPet } from '@/lib/selectors';
import { radius, useTheme } from '@/lib/theme';

/**
 * General, non-procedural safety notes while getting professional help. PetTrack deliberately gives no
 * treatment instructions: anything medical is for a veterinarian to decide.
 */
export const WHILE_YOU_GET_HELP = [
  'Stay calm and keep yourself safe – a frightened or injured animal may bite or scratch.',
  'Call your vet or an emergency clinic first and follow their instructions.',
  'Do not give food, water, human medicine or home remedies unless a vet tells you to.',
  'If something was swallowed, bring the packaging or a sample with you.',
  'Keep your pet as still and quiet as possible during the trip.',
];

export default function Sos() {
  const c = useTheme();
  const { t } = useTranslation();
  const view = useSelectedPet();
  const pet = view.pet;
  const [card, setCard] = useState(false);
  const tel = (n: string) => Linking.openURL(`tel:${n.replace(/[^\d+]/g, '')}`);
  const lines = hotlines(deviceRegion());

  return (
    <View style={{ flex: 1, backgroundColor: c.canvas }}>
      <SafeAreaView edges={['top']} style={{ backgroundColor: c.danger }}>
        <Row style={{ justifyContent: 'space-between', padding: 18 }}>
          <View>
            <T variant="eyebrow" color="#FFFFFFB3">{t('Emergency')}</T>
            <T variant="display" color="#fff" style={{ fontSize: 30 }}>{t('Stay calm. Act fast.')}</T>
          </View>
          <Pressable onPress={() => router.back()} accessibilityRole="button" accessibilityLabel={t('Close')} hitSlop={10}
            style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: '#FFFFFF33', alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="close" size={20} color="#fff" />
          </Pressable>
        </Row>
      </SafeAreaView>
      <ScrollView keyboardShouldPersistTaps="handled" automaticallyAdjustKeyboardInsets keyboardDismissMode="interactive" contentContainerStyle={{ padding: 20, gap: 14, paddingBottom: 60 }}>
        {!!pet?.vetPhone && <Button icon="call" tint={c.danger} title={t('Call {{a}}', { a: pet.vetClinic || t('Veterinarian') })} onPress={() => tel(pet.vetPhone)} />}
        <Button icon="navigate" tint={c.ink} title={t('Find an emergency vet nearby')} onPress={() => Linking.openURL('https://maps.apple.com/?q=emergency%20veterinarian')} />
        {lines.map((h) => <Button key={h.id} variant="soft" tint={c.danger} icon="call-outline" title={`${h.name} · ${h.phone}`} onPress={() => tel(h.phone)} />)}
        <Button variant="soft" tint={c.sky} icon="id-card-outline" title={t('Show emergency card to staff')} onPress={() => setCard(true)} />

        <T variant="title" style={{ marginTop: 8 }}>{t('While you get help')}</T>
        <Card>
          {WHILE_YOU_GET_HELP.map((line) => (
            <Row key={line} gap={10} align="flex-start">
              <Ionicons name="ellipse" size={8} color={c.danger} style={{ marginTop: 7 }} />
              <T style={{ flex: 1 }}>{t(line)}</T>
            </Row>
          ))}
        </Card>
        <T variant="caption" center>{t('PetTrack does not give medical or first-aid instructions and cannot assess an emergency. Always contact a veterinarian.')}</T>
      </ScrollView>


      <Modal visible={card} animationType="fade" onRequestClose={() => setCard(false)}>
        <Pressable style={{ flex: 1, backgroundColor: '#fff', padding: 28, justifyContent: 'center', gap: 14 }} onPress={() => setCard(false)} accessibilityHint={t('Tap to close')}>
          <T variant="eyebrow" color={c.danger}>{t('Emergency card')}</T>
          <T variant="display" color="#17201C" style={{ fontSize: 44, lineHeight: 50 }}>{pet?.name}</T>
          {[
            ['Species', [pet?.species, pet?.breed].filter(Boolean).join(' · ')],
            ['Weight', view.latestWeight ? `${view.latestWeight.kg.toFixed(1)} kg / ${(view.latestWeight.kg * 2.2046).toFixed(1)} lb` : ''],
            ['Allergies', pet?.allergies], ['Conditions', pet?.conditions],
            ['Current medication', view.activeMedications.map((m) => `${m.name} ${m.dosage}`).join(', ')],
            ['Microchip', pet?.microchip], ['Veterinarian', [pet?.vetClinic, pet?.vetPhone].filter(Boolean).join(' · ')],
          ].map(([k, v]) => (
            <View key={k}>
              <T variant="caption" color="#5D6962" style={{ fontSize: 14 }}>{t(k ?? '')}</T>
              <T color="#17201C" style={{ fontSize: 22, lineHeight: 28 }}>{v || '—'}</T>
            </View>
          ))}
        </Pressable>
      </Modal>
    </View>
  );
}

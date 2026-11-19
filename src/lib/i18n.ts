import { getLocales } from 'expo-localization';
import i18n from 'i18next';
import { initReactI18next, useTranslation } from 'react-i18next';
import de from '../i18n/de.json';
import es from '../i18n/es.json';
import fr from '../i18n/fr.json';
import nl from '../i18n/nl.json';

export const LANGUAGES = [
  { code: 'en', name: 'English' },
  { code: 'es', name: 'Español' },
  { code: 'de', name: 'Deutsch' },
  { code: 'fr', name: 'Français' },
  { code: 'nl', name: 'Nederlands' },
];

export function deviceLanguage(): string {
  const code = getLocales()[0]?.languageCode ?? 'en';
  return LANGUAGES.some((l) => l.code === code) ? code : 'en';
}

export function deviceRegion(): string {
  return getLocales()[0]?.regionCode ?? 'US';
}

export function deviceLocale(): string {
  return getLocales()[0]?.languageTag ?? 'en-US';
}

i18n.use(initReactI18next).init({
  // English source strings are the keys, so English needs no resource file.
  resources: { es: { translation: es }, de: { translation: de }, fr: { translation: fr }, nl: { translation: nl } },
  lng: deviceLanguage(),
  fallbackLng: false,
  keySeparator: false,
  nsSeparator: false,
  interpolation: { escapeValue: false },
  returnEmptyString: false,
});

export default i18n;
export { useTranslation };

/** Translate outside React (notifications, PDFs). */
export const tr = (key: string, values: Record<string, string | number> = {}) => i18n.t(key, values) as string;

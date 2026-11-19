import i18n from './i18n';
import { deviceLocale, deviceRegion } from './i18n';
import type { WeightUnitPref } from './types';

const locale = () => {
  const region = deviceRegion();
  return `${i18n.language}-${region}`;
};

export function resolvedUnit(pref: WeightUnitPref): 'kg' | 'lb' {
  if (pref !== 'auto') return pref;
  return deviceRegion() === 'US' ? 'lb' : 'kg';
}

export const KG_PER_LB = 0.45359237;

export function weightValue(kg: number, unit: 'kg' | 'lb'): number {
  return unit === 'lb' ? kg / KG_PER_LB : kg;
}

export function toKg(value: number, unit: 'kg' | 'lb'): number {
  return unit === 'lb' ? value * KG_PER_LB : value;
}

export function formatWeight(kg: number, unit: 'kg' | 'lb'): string {
  const v = weightValue(kg, unit);
  return `${v.toLocaleString(locale(), { maximumFractionDigits: 1 })} ${unit}`;
}

export const defaultCurrency = () => {
  const region = deviceRegion();
  if (region === 'US') return 'USD';
  if (region === 'GB') return 'GBP';
  if (region === 'CH') return 'CHF';
  return 'EUR';
};

export const CURRENCIES = ['USD', 'EUR', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'CAD'];

export function formatMoney(amount: number, currency: string): string {
  try {
    return amount.toLocaleString(locale(), { style: 'currency', currency, maximumFractionDigits: 2 });
  } catch {
    return `${amount.toFixed(2)} ${currency}`;
  }
}

export function formatDate(d: string | Date, style: 'short' | 'medium' | 'long' | 'full' = 'medium'): string {
  const date = new Date(d);
  const opts: Intl.DateTimeFormatOptions =
    style === 'short' ? { day: 'numeric', month: 'short' }
      : style === 'medium' ? { day: 'numeric', month: 'short', year: 'numeric' }
        : style === 'long' ? { day: 'numeric', month: 'long', year: 'numeric' }
          : { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
  return date.toLocaleDateString(locale(), opts);
}

export function formatTime(d: string | Date): string {
  return new Date(d).toLocaleTimeString(locale(), { hour: 'numeric', minute: '2-digit' });
}

export function formatSlotTime(hour: number, minute: number): string {
  const d = new Date();
  d.setHours(hour, minute, 0, 0);
  return formatTime(d);
}

export function formatDateTime(d: string | Date): string {
  return `${formatDate(d, 'short')}, ${formatTime(d)}`;
}

/** "Today", "Tomorrow", "In 3 days", "2 days ago" in the current language. */
export function relativeDay(d: string | Date, now = new Date()): string {
  const start = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const days = Math.round((start(new Date(d)) - start(now)) / 86_400_000);
  if (days === 0) return i18n.t('Today');
  if (days === 1) return i18n.t('Tomorrow');
  if (days === -1) return i18n.t('Yesterday');
  return days > 0 ? i18n.t('In {{a}} days', { a: days }) : i18n.t('{{a}} days ago', { a: -days });
}

export function relativeTime(d: string | Date, now = new Date()): string {
  const minutes = Math.round((now.getTime() - new Date(d).getTime()) / 60_000);
  if (minutes >= 0 && minutes < 1) return i18n.t('Just now');
  if (minutes >= 0 && minutes < 60) return i18n.t('{{a}} min ago', { a: minutes });
  if (minutes >= 0 && minutes < 24 * 60 && new Date(d).getDate() === now.getDate()) return formatTime(d);
  return `${relativeDay(d, now)}, ${formatTime(d)}`;
}

export function percent(ratio: number): string {
  return ratio.toLocaleString(locale(), { style: 'percent', maximumFractionDigits: 0 });
}

export function parseDecimal(text: string): number | undefined {
  const n = Number(text.trim().replace(',', '.'));
  return text.trim() && Number.isFinite(n) ? n : undefined;
}

export function ageText(birth?: string, now = new Date()): string | undefined {
  if (!birth) return undefined;
  const b = new Date(birth);
  let months = (now.getFullYear() - b.getFullYear()) * 12 + now.getMonth() - b.getMonth();
  if (now.getDate() < b.getDate()) months -= 1;
  if (months >= 24) return i18n.t('{{a}} yr', { a: Math.floor(months / 12) });
  if (months >= 12) return `${i18n.t('{{a}} yr', { a: 1 })} ${i18n.t('{{a}} mo', { a: months - 12 })}`;
  if (months >= 1) return i18n.t('{{a}} mo', { a: months });
  return i18n.t('{{a}} wk', { a: Math.max(0, Math.floor((now.getTime() - b.getTime()) / (7 * 86_400_000))) });
}

const COUNTRY_EN: Record<string, string> = {
  US: 'United States', GB: 'United Kingdom', IE: 'Ireland', DE: 'Germany', FR: 'France', ES: 'Spain', NL: 'Netherlands',
  IT: 'Italy', PT: 'Portugal', BE: 'Belgium', AT: 'Austria', CH: 'Switzerland', SE: 'Sweden', DK: 'Denmark', PL: 'Poland',
  FI: 'Finland', MT: 'Malta', NO: 'Norway',
};

export function countryName(code: string): string {
  try {
    const name = new Intl.DisplayNames([i18n.language], { type: 'region' }).of(code);
    if (name && name !== code) return name;
  } catch {
    // Older JS engines without Intl.DisplayNames fall back to English.
  }
  return COUNTRY_EN[code] ?? code;
}

export { deviceLocale };

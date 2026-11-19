/**
 * Rule-based parser for vet reports and invoices in English, Spanish, German, French and Dutch.
 * Looks for labelled fields ("Diagnosis:", "Diagnose:", "Diagnóstico:" …), dates, weights, totals and
 * vaccine names. The result is always shown to the user for review before it is saved.
 */
export interface ParsedReport {
  visitDate?: Date;
  clinic: string;
  vet: string;
  reason: string;
  diagnosis: string;
  treatment: string;
  weightKg?: number;
  totalCost?: number;
  currency?: string;
  vaccines: string[];
  followUp?: Date;
  rawText: string;
}

const reasonKeys = ['reason for visit', 'chief complaint', 'presenting complaint', 'reason', 'complaint', 'motivo de consulta', 'motivo de la visita', 'motivo', 'vorstellungsgrund', 'grund des besuchs', 'anlass', 'grund', 'motif de consultation', 'motif de la visite', 'motif', 'reden van bezoek', 'reden', 'klacht'];
const diagnosisKeys = ['diagnosis', 'assessment', 'findings', 'diagnóstico', 'diagnostico', 'hallazgos', 'diagnose', 'befund', 'befunde', 'diagnostic', 'conclusion', 'bevindingen'];
const treatmentKeys = ['treatment plan', 'treatment', 'therapy', 'prescription', 'plan', 'medication', 'tratamiento', 'receta', 'medicación', 'behandlung', 'therapie', 'medikation', 'traitement', 'ordonnance', 'behandeling', 'medicatie'];
const vetKeys = ['attending veterinarian', 'veterinarian', 'attending', 'doctor', 'vet', 'veterinario', 'veterinaria', 'tierärztin', 'tierarzt', 'behandelnder tierarzt', 'vétérinaire', 'veterinaire', 'dierenarts'];
const clinicKeys = ['clinic', 'hospital', 'practice', 'clínica', 'clinica', 'tierklinik', 'praxis', 'tierarztpraxis', 'clinique', 'dierenkliniek', 'kliniek', 'praktijk'];
const dateKeys = ['visit date', 'date of visit', 'date', 'fecha', 'datum', 'date de visite', 'bezoekdatum'];
const followUpKeys = ['next appointment', 'next visit', 'follow-up', 'follow up', 'recheck', 'próxima cita', 'proxima cita', 'revisión', 'nächster termin', 'wiedervorstellung', 'kontrolle', 'prochain rendez-vous', 'prochaine visite', 'contrôle', 'volgende afspraak', 'controle', 'hercontrole'];
const weightKeys = ['weight', 'body weight', 'peso', 'gewicht', 'körpergewicht', 'poids'];
const totalKeys = ['total due', 'amount due', 'grand total', 'total', 'balance', 'importe total', 'total a pagar', 'importe', 'gesamtbetrag', 'gesamt', 'summe', 'rechnungsbetrag', 'betrag', 'montant total', 'montant', 'totaal', 'te betalen', 'bedrag'];
const clinicHints = ['clinic', 'hospital', 'veterinary', 'animal', 'vet ', 'clínica', 'veterinaria', 'tierarzt', 'tierklinik', 'clinique', 'vétérinaire', 'dierenarts', 'dierenkliniek'];

export const VACCINE_ALIASES: [string, string[]][] = [
  ['Rabies', ['rabies', 'tollwut', 'rage', 'rabia', 'antirrábica', 'antirrabica', 'hondsdolheid']],
  ['DHPP', ['dhpp', 'dhlpp', 'dappv', 'dapp', 'da2pp', 'dhppi', 'shp', 'shpp', 'shppi', 'shppil', 'chppi']],
  ['Leptospirosis', ['leptospirosis', 'leptospirose', 'lepto']],
  ['Bordetella', ['bordetella', 'kennel cough', 'zwingerhusten', 'toux du chenil', 'tos de las perreras', 'kennelhoest']],
  ['Parvovirus', ['parvovirus', 'parvovirose', 'parvo']],
  ['Distemper', ['distemper', 'staupe', 'maladie de carré', 'moquillo', 'hondenziekte']],
  ['Lyme', ['lyme', 'borreliose', 'borreliosis']],
  ['Canine Influenza', ['canine influenza', 'h3n2']],
  ['FVRCP', ['fvrcp', 'rcp', 'katzenschnupfen', 'coryza']],
  ['FeLV', ['felv', 'feline leukemia', 'leukose', 'leucose', 'leucemia felina', 'leukemie']],
  ['Panleukopenia', ['panleukopenia', 'panleukopenie', 'katzenseuche', 'typhus', 'panleucopenia', 'kattenziekte']],
  ['RHDV', ['rhdv', 'rhd2', 'vhd']],
  ['Myxomatosis', ['myxomatosis', 'myxomatose', 'mixomatosis']],
];

const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function labeledValue(lines: string[], keys: string[], requireColon = false): string | undefined {
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lower = line.toLowerCase();
    for (const key of keys) {
      if (!lower.startsWith(key)) continue;
      const rest = line.slice(key.length);
      if (requireColon && !rest.trim().startsWith(':')) continue;
      if (rest.length === 0) return lines[i + 1];
      const first = rest[0];
      if (![':', '-', '–', ' ', '\t'].includes(first)) continue;
      const value = rest.replace(/^[\s:\-–\t]+/, '').trim();
      if (!value) return lines[i + 1];
      if (first === ' ' && !rest.includes(':') && key.length < 6) continue;
      return value;
    }
  }
  return undefined;
}

export function doctorName(lines: string[]): string | undefined {
  const re = /\b(Dr|Dra|Drs|DVM)\.?\s+[A-ZÀ-Ý][\p{L}'-]+(\s+[A-ZÀ-Ý][\p{L}'-]+)?/u;
  for (const line of lines) {
    const m = line.match(re);
    if (m) return m[0];
  }
  return undefined;
}

export function clinicName(lines: string[]): string | undefined {
  return lines.slice(0, 6).find((line) => {
    const lower = line.toLowerCase();
    return clinicHints.some((h) => lower.includes(h)) && line.length <= 60 && !lower.includes(':');
  });
}

export function weightIn(line: string): number | undefined {
  const m = line.match(/(\d{1,3}(?:[.,]\d{1,2})?)\s*(kg|kgs|kilo|kilogram|kilogramm|kilogramos|lbs|lb|pounds)\b/i);
  if (!m) return undefined;
  const value = parseFloat(m[1].replace(',', '.'));
  const unit = m[2].toLowerCase();
  const kg = unit.startsWith('lb') || unit === 'pounds' ? value * 0.45359237 : value;
  return Math.round(kg * 100) / 100;
}

export function normalizeNumber(raw: string): number | undefined {
  let text = raw.replace(/[\s\u00A0]/g, '');
  const lastDot = text.lastIndexOf('.');
  const lastComma = text.lastIndexOf(',');
  if (lastDot >= 0 && lastComma >= 0) {
    text = lastDot > lastComma ? text.replace(/,/g, '') : text.replace(/\./g, '').replace(',', '.');
  } else if (lastComma >= 0) {
    const decimals = text.length - lastComma - 1;
    text = decimals === 3 ? text.replace(/,/g, '') : text.replace(',', '.');
  } else if (lastDot >= 0) {
    const decimals = text.length - lastDot - 1;
    const dots = (text.match(/\./g) ?? []).length;
    if (decimals === 3 || dots > 1) text = text.replace(/\./g, '');
  }
  const n = Number(text);
  return Number.isFinite(n) ? n : undefined;
}

export function amountIn(line: string): number | undefined {
  const matches = line.match(/\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?/g);
  if (!matches?.length) return undefined;
  return normalizeNumber(matches[matches.length - 1]);
}

export function currencyIn(text: string): string | undefined {
  const upper = text.toUpperCase();
  if (text.includes('€') || upper.includes('EUR')) return 'EUR';
  if (text.includes('£') || upper.includes('GBP')) return 'GBP';
  if (upper.includes('CHF')) return 'CHF';
  if (upper.includes('SEK')) return 'SEK';
  if (upper.includes('DKK')) return 'DKK';
  if (upper.includes('NOK')) return 'NOK';
  if (text.includes('$') || upper.includes('USD')) return 'USD';
  return undefined;
}

function makeDate(y: number, m: number, d: number): Date | undefined {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1990 || y > 2100) return undefined;
  return new Date(y, m - 1, d, 12);
}

const MONTHS: Record<string, number> = {
  jan: 1, january: 1, enero: 1, januar: 1, janvier: 1, januari: 1,
  feb: 2, february: 2, febrero: 2, februar: 2, février: 2, februari: 2,
  mar: 3, march: 3, marzo: 3, märz: 3, mars: 3, maart: 3,
  apr: 4, april: 4, abril: 4, avril: 4,
  may: 5, mayo: 5, mai: 5, mei: 5,
  jun: 6, june: 6, junio: 6, juni: 6, juin: 6,
  jul: 7, july: 7, julio: 7, juli: 7, juillet: 7,
  aug: 8, august: 8, agosto: 8, août: 8, augustus: 8,
  sep: 9, sept: 9, september: 9, septiembre: 9, septembre: 9,
  oct: 10, october: 10, octubre: 10, oktober: 10, octobre: 10,
  nov: 11, november: 11, noviembre: 11, novembre: 11,
  dec: 12, december: 12, diciembre: 12, dezember: 12, décembre: 12,
};

export function firstDate(text: string, monthFirst: boolean): Date | undefined {
  let m = text.match(/\b(\d{4})-(\d{1,2})-(\d{1,2})\b/);
  if (m) return makeDate(+m[1], +m[2], +m[3]);
  m = text.match(/\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b/);
  if (m) {
    let a = +m[1];
    let b = +m[2];
    let y = +m[3];
    if (y < 100) y += 2000;
    const dotted = text.includes('.') && !text.includes('/');
    let mf = monthFirst && !dotted;
    if (a > 12) mf = false;
    if (b > 12) mf = true;
    if (mf) [a, b] = [b, a];
    return makeDate(y, b, a);
  }
  // "March 3, 2026" / "3 mars 2026" / "3. März 2026"
  m = text.match(/\b([A-Za-zÀ-ÿ]{3,10})\.?\s+(\d{1,2}),?\s+(\d{4})\b/);
  if (m && MONTHS[m[1].toLowerCase()]) return makeDate(+m[3], MONTHS[m[1].toLowerCase()], +m[2]);
  m = text.match(/\b(\d{1,2})\.?\s+([A-Za-zÀ-ÿ]{3,10})\.?\s+(\d{4})\b/);
  if (m && MONTHS[m[2].toLowerCase()]) return makeDate(+m[3], MONTHS[m[2].toLowerCase()], +m[1]);
  return undefined;
}

export function vaccinesIn(text: string): string[] {
  const lower = text.toLowerCase();
  return VACCINE_ALIASES.filter(([, aliases]) =>
    aliases.some((a) => new RegExp(`(^|[^\\p{L}])${escapeRe(a)}($|[^\\p{L}])`, 'u').test(lower)),
  ).map(([name]) => name);
}

export function parseReport(text: string, region = 'US', now = new Date()): ParsedReport {
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const monthFirst = region === 'US';
  const report: ParsedReport = {
    clinic: labeledValue(lines, clinicKeys, true) ?? clinicName(lines) ?? '',
    vet: labeledValue(lines, vetKeys) ?? doctorName(lines) ?? '',
    reason: labeledValue(lines, reasonKeys) ?? '',
    diagnosis: labeledValue(lines, diagnosisKeys) ?? '',
    treatment: labeledValue(lines, treatmentKeys) ?? '',
    vaccines: vaccinesIn(text),
    rawText: text,
  };
  const dateValue = labeledValue(lines, dateKeys);
  if (dateValue) report.visitDate = firstDate(dateValue, monthFirst);
  const follow = labeledValue(lines, followUpKeys);
  if (follow) report.followUp = firstDate(follow, monthFirst);
  if (!report.visitDate) {
    const limit = now.getTime() + 86_400_000;
    for (const line of lines) {
      const d = firstDate(line, monthFirst);
      if (d && d.getTime() <= limit) { report.visitDate = d; break; }
    }
  }
  const weightLine = lines.find((l) => weightKeys.some((k) => l.toLowerCase().includes(k)));
  report.weightKg = (weightLine ? weightIn(weightLine) : undefined) ?? lines.map(weightIn).find((w) => w !== undefined);
  const totalLine = [...lines].reverse().find((l) => {
    const lower = l.toLowerCase();
    return totalKeys.some((k) => lower.includes(k)) && !lower.includes('subtotal') && amountIn(l) !== undefined;
  });
  if (totalLine) {
    report.totalCost = amountIn(totalLine);
    report.currency = currencyIn(totalLine) ?? currencyIn(text);
  }
  return report;
}

export const SAMPLE_REPORT = `Riverside Animal Clinic
Dr. Emma Hart
Date: 11/12/2026
Reason for visit: Itchy ears, head shaking
Weight: 28.4 kg
Diagnosis: Otitis externa (left ear)
Treatment: Ear drops twice daily for 10 days, cone if scratching
Rabies vaccine administered
Next appointment: 11/26/2026
Subtotal 120.00
Total due $145.50`;

import { Platform } from 'react-native';
import * as Print from 'expo-print';
import * as Sharing from 'expo-sharing';
import QRCode from 'qrcode';
import { addDays } from './dates';
import { ageText, countryName, formatDate, formatDateTime, formatMoney, formatWeight } from './format';
import { tr } from './i18n';
import type { PetView } from './selectors';
import type { Claim, Collections, Pet, SymptomCase, SymptomEntry, VetVisit } from './types';

const esc = (s: string | number | undefined | null) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

const dash = (s?: string | number) => (s === undefined || s === '' ? '—' : esc(s));

const BASE_CSS = `
  @page { margin: 28px; }
  * { box-sizing: border-box; }
  body { font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif; color: #17201C; font-size: 11px; line-height: 1.45; margin: 0; }
  .eyebrow { font-size: 9px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: #CF5F3B; }
  h1 { font-family: Georgia, 'New York', serif; font-size: 30px; font-weight: 600; margin: 2px 0 0; }
  h2 { font-size: 9px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; color: #CF5F3B; margin: 18px 0 6px; }
  header { display: flex; align-items: center; gap: 16px; border-bottom: 1.5px solid #17201C; padding-bottom: 10px; }
  header img { width: 72px; height: 72px; border-radius: 50%; object-fit: cover; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 24px; }
  .row { display: flex; gap: 8px; padding: 2px 0; }
  .row .k { width: 110px; color: #5D6962; flex: none; }
  .row .v { font-weight: 500; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 9px; color: #5D6962; font-weight: 600; padding: 5px 4px; border-bottom: 0.5px solid #E3DBCE; }
  td { padding: 5px 4px; border-bottom: 0.5px solid #E3DBCE; vertical-align: top; }
  .entry { display: flex; gap: 12px; padding: 6px 0; border-bottom: 0.5px solid #E3DBCE; page-break-inside: avoid; }
  .entry img { width: 150px; height: 112px; object-fit: cover; border-radius: 6px; flex: none; }
  .muted { color: #5D6962; }
  footer { margin-top: 18px; font-size: 8px; color: #5D6962; }
`;

const page = (title: string, body: string) =>
  `<!doctype html><html><head><meta charset="utf-8"><title>${esc(title)}</title><style>${BASE_CSS}</style></head><body>${body}
  <footer>${esc(tr('Generated with PetTrack · {{a}}', { a: formatDateTime(new Date()) }))}</footer></body></html>`;

const row = (k: string, v?: string | number) => `<div class="row"><span class="k">${esc(tr(k))}</span><span class="v">${dash(v)}</span></div>`;

const header = (eyebrow: string, pet: Pet, subtitle = '') => `
  <header>${pet.photo ? `<img src="${pet.photo}">` : ''}
    <div><div class="eyebrow">${esc(tr(eyebrow))}</div><h1>${esc(pet.name)}</h1>${subtitle ? `<div class="muted">${esc(subtitle)}</div>` : ''}</div>
  </header>`;

const severity = (n: number) => tr(['Mild', 'Mild', 'Noticeable', 'Moderate', 'Strong', 'Severe'][Math.max(0, Math.min(5, n))]);

export function passportHtml(v: PetView, unit: 'kg' | 'lb'): string {
  const pet = v.pet!;
  const vacc = v.vaccinations.map((x) => `<tr><td>${esc(x.name)}</td><td>${formatDate(x.dateGiven)}</td><td>${x.nextDue ? formatDate(x.nextDue) : '—'}</td><td>${dash(x.batch)}</td></tr>`).join('');
  const visits = v.visits.slice(0, 15).map((x) => `<div class="entry"><div><b>${esc(x.reason || x.diagnosis || tr('Vet visit'))}</b> · ${formatDate(x.date)}<br>
    ${x.diagnosis ? `<b>${esc(tr('Diagnosis'))}:</b> ${esc(x.diagnosis)}<br>` : ''}${x.treatment ? `<b>${esc(tr('Treatment'))}:</b> ${esc(x.treatment)}<br>` : ''}
    <span class="muted">${esc([x.clinic, x.vet].filter(Boolean).join(' · '))}</span></div></div>`).join('');
  const weights = v.weights.slice(-12).reverse().map((w) => `<tr><td>${formatDate(w.date)}</td><td>${formatWeight(w.kg, unit)}</td><td>${dash(w.note)}</td></tr>`).join('');
  const meds = v.activeMedications.map((m) => `<tr><td>${esc(m.name)}</td><td>${dash(m.dosage)}</td><td>${dash(m.instructions)}</td></tr>`).join('');
  return page(`${pet.name} – ${tr('Health passport')}`, `
    ${header('PET HEALTH PASSPORT', pet, [pet.breed, ageText(pet.birthDate)].filter(Boolean).join(' · '))}
    <div class="grid">
      <div><h2>${esc(tr('Identification'))}</h2>
        ${row('Species', tr(cap(pet.species)))}${row('Breed', pet.breed)}${row('Sex', tr(cap(pet.sex)) + (pet.neutered ? ` · ${tr('Neutered')}` : ''))}
        ${row('Born', pet.birthDate ? formatDate(pet.birthDate, 'long') : '')}${row('Microchip', pet.microchip)}
        ${row('Latest weight', v.latestWeight ? `${formatWeight(v.latestWeight.kg, unit)} (${formatDate(v.latestWeight.date)})` : '')}</div>
      <div><h2>${esc(tr('Emergency'))}</h2>${row('Allergies', pet.allergies)}${row('Conditions', pet.conditions)}${row('Blood type', pet.bloodType)}${row('Notes', pet.emergencyNotes)}</div>
      <div><h2>${esc(tr('Veterinarian'))}</h2>${row('Clinic', pet.vetClinic)}${row('Veterinarian', pet.vetName)}${row('Phone', pet.vetPhone)}${row('Email', pet.vetEmail)}</div>
      <div><h2>${esc(tr('Insurance'))}</h2>${row('Provider', pet.insuranceProvider)}${row('Policy number', pet.insurancePolicy)}</div>
    </div>
    <h2>${esc(tr('Vaccinations'))}</h2>
    <table><tr><th>${esc(tr('Vaccine'))}</th><th>${esc(tr('Given'))}</th><th>${esc(tr('Next due'))}</th><th>${esc(tr('Batch'))}</th></tr>${vacc || `<tr><td colspan="4">${esc(tr('None recorded'))}</td></tr>`}</table>
    ${meds ? `<h2>${esc(tr('Current medication'))}</h2><table><tr><th>${esc(tr('Medication'))}</th><th>${esc(tr('Dosage'))}</th><th>${esc(tr('Instructions'))}</th></tr>${meds}</table>` : ''}
    <h2>${esc(tr('Vet visits'))}</h2>${visits || `<p>${esc(tr('No visits recorded'))}</p>`}
    <h2>${esc(tr('Weight history'))}</h2>
    <table><tr><th>${esc(tr('Date'))}</th><th>${esc(tr('Weight'))}</th><th>${esc(tr('Note'))}</th></tr>${weights || `<tr><td colspan="3">${esc(tr('None recorded'))}</td></tr>`}</table>
    <p class="muted">${esc(tr('Information provided by the owner. Please verify with original records.'))}</p>`);
}

export function symptomHtml(pet: Pet, c: SymptomCase, entries: SymptomEntry[]): string {
  const items = entries.map((e) => `<div class="entry">${e.photo ? `<img src="${e.photo}">` : ''}<div>
    <b>${esc(formatDate(e.date, 'full'))}, ${esc(new Date(e.date).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }))}</b><br>
    ${esc(severity(e.severity))}<br>${esc(e.note)}</div></div>`).join('');
  return page(c.title, `${header('SYMPTOM REPORT', pet, `${c.title} · ${c.area} · ${tr('Since {{a}}', { a: formatDate(c.start, 'long') })}`)}
    ${c.notes ? `<p>${esc(c.notes)}</p>` : ''}${items}`);
}

export function claimHtml(data: Collections, pet: Pet, claim: Claim, visit: VetVisit): string {
  const start = addDays(visit.date, -30).toISOString();
  const end = addDays(visit.date, 1).toISOString();
  const cases = data.symptomCases.filter((c) => c.petId === pet.id);
  const entries = claim.includeSymptoms
    ? data.symptomEntries.filter((e) => cases.some((c) => c.id === e.caseId) && e.date >= start && e.date <= end).sort((a, b) => a.date.localeCompare(b.date))
    : [];
  const entryHtml = entries.map((e) => {
    const c = cases.find((x) => x.id === e.caseId)!;
    return `<div class="entry">${e.photo ? `<img src="${e.photo}">` : ''}<div><b>${esc(c.title)}</b> · ${esc(formatDateTime(e.date))}<br>${esc(severity(e.severity))}<br>${esc(e.note)}</div></div>`;
  }).join('');
  return page(tr('Insurance claim pack'), `${header('INSURANCE CLAIM PACK', pet)}
    <h2>${esc(tr('Claim'))}</h2>${row('Insurance company', claim.insurer)}${row('Policy number', claim.policy)}${row('Claim number', claim.claimNo)}${row('Amount claimed', formatMoney(claim.claimed, claim.currency))}
    <h2>${esc(tr('Pet'))}</h2>${row('Species', tr(cap(pet.species)))}${row('Breed', pet.breed)}${row('Born', pet.birthDate ? formatDate(pet.birthDate, 'long') : '')}${row('Microchip', pet.microchip)}
    <h2>${esc(tr('Treatment'))}</h2>${row('Date', formatDate(visit.date, 'long'))}${row('Clinic', visit.clinic)}${row('Veterinarian', visit.vet)}${row('Reason', visit.reason)}${row('Diagnosis', visit.diagnosis)}${row('Treatment', visit.treatment)}${row('Invoice total', visit.cost !== undefined ? formatMoney(visit.cost, visit.currency) : '')}
    ${pet.conditions ? `<h2>${esc(tr('Known conditions'))}</h2><p>${esc(pet.conditions)}</p>` : ''}
    ${entryHtml ? `<h2>${esc(tr('Symptom history before the visit'))}</h2>${entryHtml}` : ''}
    ${visit.attachment ? `<h2>${esc(tr('Invoice / vet report'))}</h2><img src="${visit.attachment}" style="width:100%;border:0.5px solid #E3DBCE">` : ''}
    <p class="muted">${esc(tr("Please attach your insurer's claim form if required."))}</p>`);
}

export function visitPrepHtml(v: PetView, summary: { since: string; weight: string; meals: string; water: string }): string {
  const pet = v.pet!;
  const cases = v.symptomCases.filter((c) => v.lastUpdated(c) >= summary.since).map((c) => {
    const last = v.entriesFor(c).at(-1);
    return `<div class="entry">${last?.photo ? `<img src="${last.photo}">` : ''}<div><b>${esc(c.title)}</b><br><span class="muted">${esc(c.area)} · ${esc(tr('Since {{a}}', { a: formatDate(c.start) }))}</span><br>${last ? `${esc(severity(last.severity))} · ${esc(last.note)}` : ''}</div></div>`;
  }).join('');
  return page(tr('Pre-visit summary'), `${header('PRE-VISIT SUMMARY', pet, tr('Since {{a}}', { a: formatDate(summary.since, 'long') }))}
    <h2>${esc(tr('Body & appetite'))}</h2>${row('Weight', summary.weight)}${row('Meals per day (last 14 days)', summary.meals)}${row('Water refills per day', summary.water)}${row('Allergies', pet.allergies)}${row('Conditions', pet.conditions)}
    <h2>${esc(tr('Symptoms'))}</h2>${cases || `<p>${esc(tr('None recorded'))}</p>`}
    <h2>${esc(tr('Current medication'))}</h2>${v.activeMedications.map((m) => row(m.name, m.dosage)).join('') || `<p>${esc(tr('None recorded'))}</p>`}
    <h2>${esc(tr('Questions'))}</h2>${v.questions.map((q) => `<p>☐ ${esc(q.text)}</p>`).join('') || `<p>${esc(tr('None recorded'))}</p>`}`);
}

export async function qrSvg(text: string, size = 200): Promise<string> {
  return QRCode.toString(text, { type: 'svg', margin: 1, width: size, color: { dark: '#12231B', light: '#FFFFFF' } });
}

export async function lostPosterHtml(pet: Pet, url: string): Promise<string> {
  const lost = pet.lost;
  const qr = await qrSvg(url, 180);
  return `<!doctype html><html><head><meta charset="utf-8"><style>${BASE_CSS}
    body { text-align: center; } .big { font-family: Georgia, serif; font-size: 64px; font-weight: 700; color: #B5382E; letter-spacing: 4px; margin: 0; }
    .photo { width: 100%; max-height: 360px; object-fit: cover; border-radius: 12px; margin: 10px 0; }
    .phone { font-size: 30px; font-weight: 700; margin: 10px 0; } .qr svg { width: 160px; height: 160px; }</style></head><body>
    <p class="big">${esc(tr('LOST PET'))}</p>
    <h1 style="font-size:40px">${esc(pet.name)}</h1>
    <p style="font-size:14px">${esc([tr(cap(pet.species)), pet.breed, pet.sex !== 'unknown' ? tr(cap(pet.sex)) : '', ageText(pet.birthDate)].filter(Boolean).join(' · '))}</p>
    ${pet.photo ? `<img class="photo" src="${pet.photo}">` : ''}
    ${lost?.lastSeen ? `<p style="font-size:15px"><b>${esc(tr('Last seen'))}:</b> ${esc(lost.lastSeen)} · ${esc(formatDate(lost.since, 'long'))}</p>` : ''}
    ${lost?.message ? `<p style="font-size:14px">${esc(lost.message)}</p>` : ''}
    ${lost?.reward ? `<p style="font-size:16px"><b>${esc(tr('Reward'))}:</b> ${esc(lost.reward)}</p>` : ''}
    <p class="phone">${esc(lost?.contactPhone || '')}</p>
    <div class="qr">${qr}</div><p>${esc(tr('Scan to see details and contact the owner'))}</p></body></html>`;
}

/** Native: creates a PDF and opens the share sheet. Web: returns the HTML so it can be previewed. */
export async function shareHtmlAsPdf(html: string, fileName: string): Promise<string | undefined> {
  if (Platform.OS === 'web') return html;
  const { uri } = await Print.printToFileAsync({ html });
  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(uri, { mimeType: 'application/pdf', UTI: 'com.adobe.pdf', dialogTitle: fileName });
  }
  return undefined;
}

export const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
export { countryName };

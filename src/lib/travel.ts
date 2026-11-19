import { addDays, addMonths, startOfDay } from './dates';
import type { Pet, Species, Vaccination } from './types';

/**
 * Travel rules between the US and Europe.
 * Verify before every trip, rules change:
 * - USDA APHIS Pet Travel: https://www.aphis.usda.gov/pet-travel
 * - EU Regulation (EU) 576/2013 & 577/2013
 * - UK: https://www.gov.uk/bring-pet-to-great-britain
 * - CDC dog import rules (since 1 Aug 2024): https://www.cdc.gov/importation/dogs
 */
export interface Destination { code: string; flag: string; tapewormForDogs: boolean }

export const DESTINATIONS: Destination[] = [
  { code: 'US', flag: '🇺🇸', tapewormForDogs: false },
  { code: 'GB', flag: '🇬🇧', tapewormForDogs: true },
  { code: 'IE', flag: '🇮🇪', tapewormForDogs: true },
  { code: 'DE', flag: '🇩🇪', tapewormForDogs: false },
  { code: 'FR', flag: '🇫🇷', tapewormForDogs: false },
  { code: 'ES', flag: '🇪🇸', tapewormForDogs: false },
  { code: 'NL', flag: '🇳🇱', tapewormForDogs: false },
  { code: 'IT', flag: '🇮🇹', tapewormForDogs: false },
  { code: 'PT', flag: '🇵🇹', tapewormForDogs: false },
  { code: 'BE', flag: '🇧🇪', tapewormForDogs: false },
  { code: 'AT', flag: '🇦🇹', tapewormForDogs: false },
  { code: 'CH', flag: '🇨🇭', tapewormForDogs: false },
  { code: 'SE', flag: '🇸🇪', tapewormForDogs: false },
  { code: 'DK', flag: '🇩🇰', tapewormForDogs: false },
  { code: 'PL', flag: '🇵🇱', tapewormForDogs: false },
  { code: 'FI', flag: '🇫🇮', tapewormForDogs: true },
  { code: 'MT', flag: '🇲🇹', tapewormForDogs: true },
  { code: 'NO', flag: '🇳🇴', tapewormForDogs: true },
];

export function destination(code: string): Destination {
  return DESTINATIONS.find((d) => d.code === code) ?? DESTINATIONS[3];
}

export type StepState = 'done' | 'ready' | 'upcoming' | 'overdue';

export interface TravelStep {
  id: string;
  icon: string;
  /** English source strings, translated at render time. */
  title: string;
  detail: string;
  windowStart?: Date;
  deadline?: Date;
  autoSatisfied: boolean;
  recommended: boolean;
}

export interface PetFacts {
  species: Species;
  birthDate?: Date;
  microchip: string;
  rabiesGiven?: Date;
  rabiesValidUntil?: Date;
}

const RABIES = /rabies|tollwut|\brage\b|rabia|hondsdolheid/i;

export function petFacts(pet: Pet, vaccinations: Vaccination[]): PetFacts {
  const rabies = vaccinations
    .filter((v) => v.petId === pet.id && RABIES.test(v.name))
    .sort((a, b) => b.dateGiven.localeCompare(a.dateGiven))[0];
  return {
    species: pet.species,
    birthDate: pet.birthDate ? new Date(pet.birthDate) : undefined,
    microchip: pet.microchip,
    rabiesGiven: rabies ? new Date(rabies.dateGiven) : undefined,
    rabiesValidUntil: rabies?.nextDue ? new Date(rabies.nextDue) : undefined,
  };
}

export const hasISOMicrochip = (chip: string) => chip.replace(/\D/g, '').length === 15;

export function stepState(step: TravelStep, completed: boolean, now = new Date()): StepState {
  if (completed || step.autoSatisfied) return 'done';
  if (step.deadline && step.deadline < startOfDay(now)) return 'overdue';
  if (step.windowStart && step.windowStart > now) return 'upcoming';
  return 'ready';
}

export function travelSteps(dest: Destination, arrival: Date, facts: PetFacts): TravelStep[] {
  const day = (offset: number) => addDays(startOfDay(arrival), offset);
  return dest.code === 'US' ? toUS(arrival, facts, day) : toEurope(dest, arrival, facts, day);
}

function toEurope(dest: Destination, arrival: Date, f: PetFacts, day: (n: number) => Date): TravelStep[] {
  const steps: TravelStep[] = [];
  steps.push({
    id: 'microchip', icon: 'radio-outline', title: 'ISO microchip',
    detail: '15-digit ISO 11784/11785 microchip, implanted on or before the day of the rabies vaccination.',
    deadline: day(-21), autoSatisfied: hasISOMicrochip(f.microchip), recommended: false,
  });
  const validAtArrival = !f.rabiesValidUntil || f.rabiesValidUntil >= arrival;
  const earlyEnough = !!f.rabiesGiven && f.rabiesGiven <= day(-21);
  steps.push({
    id: 'rabies', icon: 'medkit-outline', title: 'Rabies vaccination',
    detail: 'Pet must be at least 12 weeks old. A first vaccination must be given at least 21 days before arrival; boosters given on time need no wait.',
    deadline: day(-21), autoSatisfied: validAtArrival && earlyEnough, recommended: false,
  });
  if (dest.tapewormForDogs && f.species === 'dog') {
    steps.push({
      id: 'tapeworm', icon: 'medical-outline', title: 'Tapeworm treatment by a vet',
      detail: 'Praziquantel treatment 24–120 hours (1–5 days) before arrival, recorded on the health certificate.',
      windowStart: day(-5), deadline: day(-1), autoSatisfied: false, recommended: false,
    });
  }
  steps.push({
    id: 'certificate', icon: 'document-text-outline',
    title: dest.code === 'GB' ? 'GB health certificate' : 'EU health certificate',
    detail: 'Issued by a USDA-accredited veterinarian within 10 days before arrival.',
    windowStart: day(-10), deadline: day(-2), autoSatisfied: false, recommended: false,
  });
  steps.push({
    id: 'endorsement', icon: 'ribbon-outline', title: 'USDA APHIS endorsement',
    detail: 'Submit the certificate for endorsement (online via VEHCS) right after the vet visit and before departure.',
    windowStart: day(-10), deadline: day(-1), autoSatisfied: false, recommended: false,
  });
  steps.push(airline(day));
  return steps;
}

function toUS(arrival: Date, f: PetFacts, day: (n: number) => Date): TravelStep[] {
  const steps: TravelStep[] = [];
  const rabiesOK = !!f.rabiesValidUntil && f.rabiesValidUntil >= arrival;
  if (f.species === 'dog') {
    steps.push({
      id: 'age', icon: 'calendar-outline', title: 'At least 6 months old',
      detail: 'The CDC only allows dogs that are at least 6 months old on arrival.',
      autoSatisfied: !!f.birthDate && addMonths(f.birthDate, 6) <= arrival, recommended: false,
    });
    steps.push({
      id: 'microchip', icon: 'radio-outline', title: 'ISO microchip',
      detail: 'An ISO-compatible microchip, implanted before any required rabies vaccination.',
      deadline: day(-14), autoSatisfied: hasISOMicrochip(f.microchip), recommended: false,
    });
    steps.push({
      id: 'cdcForm', icon: 'clipboard-outline', title: 'CDC Dog Import Form',
      detail: 'Submit online 2–10 days before arrival and keep the receipt for the airline and border officer.',
      windowStart: day(-10), deadline: day(-2), autoSatisfied: false, recommended: false,
    });
    steps.push({
      id: 'rabies', icon: 'medkit-outline', title: 'Rabies vaccination',
      detail: 'Not required by the CDC for dogs from rabies-free or low-risk countries, but most states and airlines expect it.',
      deadline: day(-30), autoSatisfied: rabiesOK, recommended: true,
    });
  } else {
    steps.push({
      id: 'rabies', icon: 'medkit-outline', title: 'Rabies vaccination',
      detail: 'No federal CDC rule for cats, but several states and most airlines require a current rabies vaccination.',
      deadline: day(-30), autoSatisfied: rabiesOK, recommended: true,
    });
  }
  steps.push({
    id: 'fitToFly', icon: 'pulse-outline', title: 'Fit-to-fly check',
    detail: 'Many airlines ask for a health certificate issued within 10 days of travel.',
    windowStart: day(-10), deadline: day(-1), autoSatisfied: false, recommended: true,
  });
  steps.push(airline(day));
  return steps;
}

const airline = (day: (n: number) => Date): TravelStep => ({
  id: 'airline', icon: 'airplane-outline', title: 'Airline booking & travel crate',
  detail: "Book your pet's place early and check the airline's crate size and temperature rules.",
  deadline: day(-30), autoSatisfied: false, recommended: true,
});

export function officialSource(code: string): string {
  if (code === 'US') return 'https://www.cdc.gov/importation/dogs/';
  if (code === 'GB') return 'https://www.gov.uk/bring-pet-to-great-britain';
  return 'https://www.aphis.usda.gov/pet-travel';
}

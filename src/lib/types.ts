export type ID = string;
/** ISO-8601 timestamp string. */
export type ISODate = string;

export type Species = 'dog' | 'cat' | 'rabbit' | 'bird' | 'other';
export type Sex = 'female' | 'male' | 'unknown';
export type FeedingKind = 'meal' | 'water' | 'treat';
export type LogSource = 'manual' | 'shortcut' | 'household' | 'watch';
export type ExpenseCategory = 'vet' | 'food' | 'medication' | 'insurance' | 'grooming' | 'supplies' | 'other';
export type RepeatRule = 'never' | 'daily' | 'weekly' | 'monthly' | 'yearly';
export type ReminderCategory = 'medication' | 'parasite' | 'grooming' | 'vet' | 'vaccine' | 'other';
export type ClaimStatus = 'draft' | 'submitted' | 'approved' | 'paid' | 'denied';

export interface LostMode {
  active: boolean;
  since: ISODate;
  lastSeen: string;
  message: string;
  reward: string;
  contactPhone: string;
}

export interface Pet {
  id: ID;
  name: string;
  species: Species;
  breed: string;
  birthDate?: ISODate;
  sex: Sex;
  neutered: boolean;
  colorIndex: number;
  photo?: string;
  microchip: string;
  bloodType: string;
  allergies: string;
  conditions: string;
  emergencyNotes: string;
  vetClinic: string;
  vetName: string;
  vetPhone: string;
  vetEmail: string;
  insuranceProvider: string;
  insurancePolicy: string;
  targetWeightKg?: number;
  createdAt: ISODate;
  /** Public collar-tag profile slug, set once published to the server. */
  publicSlug?: string;
  lost?: LostMode;
  activity?: 'low' | 'normal' | 'high';
  foodKcal100g?: number;
}

export interface Vaccination { id: ID; petId: ID; name: string; dateGiven: ISODate; nextDue?: ISODate; batch: string; by: string; notes: string }
export interface WeightEntry { id: ID; petId: ID; date: ISODate; kg: number; note: string }
export interface VetVisit {
  id: ID; petId: ID; date: ISODate; clinic: string; vet: string; reason: string; diagnosis: string; treatment: string;
  notes: string; cost?: number; currency: string; followUp?: ISODate; source: 'manual' | 'scan'; rawText?: string; attachment?: string;
}
export interface Expense { id: ID; petId: ID; date: ISODate; title: string; amount: number; currency: string; category: ExpenseCategory; note: string }
export interface Medication { id: ID; petId: ID; name: string; dosage: string; instructions: string; start: ISODate; end?: ISODate }
export interface FeedingSlot { id: ID; petId: ID; label: string; kind: FeedingKind; hour: number; minute: number; food: string; portion: number; enabled: boolean; notify: boolean }
export interface FeedingLog { id: ID; petId: ID; date: ISODate; kind: FeedingKind; amount: number; source: LogSource; fedBy: string; slotId?: ID }
export interface DietTransition { id: ID; petId: ID; fromFood: string; toFood: string; start: ISODate; days: number; notes: string; active: boolean }
export interface Reminder { id: ID; petId: ID; title: string; notes: string; due: ISODate; repeat: RepeatRule; category: ReminderCategory; done: boolean }
export interface SymptomCase { id: ID; petId: ID; title: string; area: string; start: ISODate; resolved: boolean; resolvedAt?: ISODate; notes: string; dailyReminder: boolean }
export interface SymptomEntry { id: ID; caseId: ID; date: ISODate; severity: number; note: string; photo?: string }
export interface TravelPlan { id: ID; petId: ID; destination: string; departure: ISODate; arrival: ISODate; done: string[]; notes: string }
export interface Claim {
  id: ID; petId: ID; visitId?: ID; insurer: string; policy: string; claimNo: string; status: ClaimStatus; claimed: number;
  reimbursed?: number; currency: string; submittedAt?: ISODate; includeSymptoms: boolean; notes: string; createdAt: ISODate;
}
export type Stool = 'normal' | 'soft' | 'diarrhea' | 'hard' | 'none';
export interface CheckIn { id: ID; petId: ID; date: ISODate; energy: number; appetite: number; stool: Stool; vomit: boolean; note: string }
export interface BcsEntry { id: ID; petId: ID; date: ISODate; score: number }
export interface VetQuestion { id: ID; petId: ID; text: string; createdAt: ISODate; answered: boolean }

export interface Collections {
  pets: Pet[];
  vaccinations: Vaccination[];
  weights: WeightEntry[];
  visits: VetVisit[];
  expenses: Expense[];
  medications: Medication[];
  slots: FeedingSlot[];
  logs: FeedingLog[];
  transitions: DietTransition[];
  reminders: Reminder[];
  symptomCases: SymptomCase[];
  symptomEntries: SymptomEntry[];
  travelPlans: TravelPlan[];
  claims: Claim[];
  questions: VetQuestion[];
  checkins: CheckIn[];
  bcs: BcsEntry[];
}

export type CollectionKey = keyof Collections;
export type ItemOf<K extends CollectionKey> = Collections[K][number];

export type WeightUnitPref = 'auto' | 'kg' | 'lb';

export interface Settings {
  selectedPetId?: ID;
  weightUnit: WeightUnitPref;
  memberName: string;
  tourDone: boolean;
  tipsSeen: string[];
  lastWhatsNew: string;
  language?: string;
  premium: { active: boolean; plan?: 'monthly' | 'yearly'; trialEndsAt?: ISODate; trialUsed: boolean };
  household: { code?: string; role: 'none' | 'owner' | 'member'; members: string[]; lastSync?: ISODate };
  deviceToken?: string;
  disclaimerAccepted?: string;
  theme?: 'system' | 'light' | 'dark';
}

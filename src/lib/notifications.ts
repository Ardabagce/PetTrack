import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import { addDays, atTime, startOfDay } from './dates';
import { newFoodRatio } from './diet';
import { countryName, percent } from './format';
import { tr } from './i18n';
import { destination, petFacts, travelSteps } from './travel';
import type { Collections, DietTransition, FeedingSlot, Pet, Reminder, SymptomCase, TravelPlan, Vaccination } from './types';

/** Local notifications. On the web build they are a no-op. */
const enabled = Platform.OS !== 'web';

if (enabled) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    }),
  });
}

export async function requestPermission(): Promise<boolean> {
  if (!enabled) return false;
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  const next = await Notifications.requestPermissionsAsync();
  return next.granted;
}

async function cancelPrefix(prefix: string) {
  if (!enabled) return;
  const all = await Notifications.getAllScheduledNotificationsAsync();
  await Promise.all(all.filter((n) => n.identifier.startsWith(prefix)).map((n) => Notifications.cancelScheduledNotificationAsync(n.identifier)));
}

async function at(identifier: string, title: string, body: string, date: Date) {
  if (!enabled || date <= new Date()) return;
  await Notifications.scheduleNotificationAsync({
    identifier,
    content: { title, body, sound: true },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date },
  });
}

export async function scheduleSlot(slot: FeedingSlot, petName: string) {
  await cancelPrefix(`slot-${slot.id}`);
  if (!enabled || !slot.enabled || !slot.notify) return;
  const body = slot.kind === 'water'
    ? tr("Time to refresh {{a}}'s water.", { a: petName })
    : slot.food ? tr("It's mealtime for {{a}}: {{b}}.", { a: petName, b: slot.food }) : tr("It's mealtime for {{a}}.", { a: petName });
  await Notifications.scheduleNotificationAsync({
    identifier: `slot-${slot.id}`,
    content: { title: `${petName} · ${slot.label}`, body, sound: true },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DAILY, hour: slot.hour, minute: slot.minute },
  });
}

export async function scheduleVaccine(v: Vaccination, petName: string) {
  await cancelPrefix(`vaccine-${v.id}`);
  if (!v.nextDue) return;
  const due = atTime(v.nextDue, 9, 0);
  await at(`vaccine-${v.id}-week`, tr('Vaccine due soon'), tr('{{a}} for {{b}} is due in 7 days.', { a: v.name, b: petName }), addDays(due, -7));
  await at(`vaccine-${v.id}-day`, tr('Vaccine due today'), tr('{{a}} for {{b}} is due today.', { a: v.name, b: petName }), due);
}

export async function scheduleReminder(r: Reminder, petName: string) {
  await cancelPrefix(`reminder-${r.id}`);
  if (!enabled || r.done) return;
  const d = new Date(r.due);
  const content = { title: r.title, body: r.notes ? `${petName} · ${r.notes}` : petName, sound: true };
  const T = Notifications.SchedulableTriggerInputTypes;
  const trigger =
    r.repeat === 'daily' ? { type: T.DAILY, hour: d.getHours(), minute: d.getMinutes() } as const
      : r.repeat === 'weekly' ? { type: T.WEEKLY, weekday: d.getDay() + 1, hour: d.getHours(), minute: d.getMinutes() } as const
        : r.repeat === 'monthly' ? { type: T.MONTHLY, day: d.getDate(), hour: d.getHours(), minute: d.getMinutes() } as const
          : r.repeat === 'yearly' ? { type: T.YEARLY, month: d.getMonth(), day: d.getDate(), hour: d.getHours(), minute: d.getMinutes() } as const
            : undefined;
  if (trigger) {
    await Notifications.scheduleNotificationAsync({ identifier: `reminder-${r.id}`, content, trigger });
  } else {
    await at(`reminder-${r.id}`, content.title, content.body, d);
  }
}

export async function scheduleTransition(t: DietTransition, petName: string) {
  await cancelPrefix(`transition-${t.id}`);
  if (!t.active) return;
  for (let day = 0; day < t.days; day++) {
    const ratio = newFoodRatio(day, t.days);
    await at(
      `transition-${t.id}-${day}`,
      tr('Food transition · Day {{a}}', { a: day + 1 }),
      tr('Mix {{a}} {{b}} with {{c}} {{d}} for {{e}}.', { a: percent(ratio), b: t.toFood, c: percent(1 - ratio), d: t.fromFood, e: petName }),
      atTime(addDays(startOfDay(t.start), day), 7, 30),
    );
  }
}

export async function scheduleSymptom(c: SymptomCase, petName: string) {
  await cancelPrefix(`symptom-${c.id}`);
  if (!enabled || c.resolved || !c.dailyReminder) return;
  await Notifications.scheduleNotificationAsync({
    identifier: `symptom-${c.id}`,
    content: {
      title: tr('Symptom diary · {{a}}', { a: petName }),
      body: tr('Take today\'s photo of “{{a}}” so your vet can see how it changes.', { a: c.title }),
      sound: true,
    },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DAILY, hour: 19, minute: 0 },
  });
}

export async function scheduleTravel(plan: TravelPlan, pet: Pet, data: Collections) {
  await cancelPrefix(`travel-${plan.id}`);
  const dest = destination(plan.destination);
  const name = countryName(dest.code);
  const title = tr('Trip to {{a}} · {{b}}', { a: name, b: pet.name });
  for (const step of travelSteps(dest, new Date(plan.arrival), petFacts(pet, data.vaccinations))) {
    if (step.autoSatisfied || plan.done.includes(step.id)) continue;
    if (step.windowStart) {
      await at(`travel-${plan.id}-${step.id}-open`, title, tr('You can do this now: {{a}}.', { a: tr(step.title) }), atTime(step.windowStart, 9, 0));
    }
    if (step.deadline) {
      await at(`travel-${plan.id}-${step.id}-due`, title, tr('2 days left: {{a}}.', { a: tr(step.title) }), atTime(addDays(step.deadline, -2), 9, 0));
    }
  }
}

export async function cancelForItem(prefix: string) {
  await cancelPrefix(prefix);
}

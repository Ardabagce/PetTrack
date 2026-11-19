import Foundation
import UserNotifications

/// Schedules local notifications for feeding times, vaccines, food transitions and custom reminders.
/// Notification identifiers are derived from model IDs so each item can be rescheduled or cancelled.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: Feeding

    func schedule(_ slot: FeedingSchedule, petName: String) {
        let id = "feeding-\(slot.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard slot.isEnabled, slot.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(petName) · \(slot.label)"
        switch slot.kind {
        case .water:
            content.body = String(localized: "Time to refresh \(petName)'s water.")
        case .meal, .treat:
            content.body = slot.foodName.isEmpty
                ? String(localized: "It's mealtime for \(petName).")
                : String(localized: "It's mealtime for \(petName): \(slot.foodName).")
        }
        content.sound = .default
        content.threadIdentifier = "feeding"

        var components = DateComponents()
        components.hour = slot.hour
        components.minute = slot.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(_ slot: FeedingSchedule) {
        center.removePendingNotificationRequests(withIdentifiers: ["feeding-\(slot.id.uuidString)"])
    }

    // MARK: Vaccines

    func schedule(_ vaccination: Vaccination, petName: String) {
        let base = "vaccine-\(vaccination.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [base + "-week", base + "-day"])
        guard let due = vaccination.nextDueDate else { return }

        let calendar = Calendar.current
        let dueMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
        if let weekBefore = calendar.date(byAdding: .day, value: -7, to: dueMorning), weekBefore > .now {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Vaccine due soon")
            content.body = String(localized: "\(vaccination.name) for \(petName) is due in 7 days.")
            content.sound = .default
            add(id: base + "-week", content: content, at: weekBefore)
        }
        if dueMorning > .now {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Vaccine due today")
            content.body = String(localized: "\(vaccination.name) for \(petName) is due today.")
            content.sound = .default
            add(id: base + "-day", content: content, at: dueMorning)
        }
    }

    func cancel(_ vaccination: Vaccination) {
        let base = "vaccine-\(vaccination.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [base + "-week", base + "-day"])
    }

    // MARK: Diet transition

    func schedule(_ transition: DietTransition, petName: String) {
        cancel(transition)
        guard transition.isActive else { return }
        let calendar = Calendar.current
        for day in 0..<transition.durationDays {
            guard let date = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: transition.startDate)),
                  let fireDate = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: date),
                  fireDate > .now else { continue }
            let ratio = DietTransitionPlan.newFoodRatio(dayIndex: day, durationDays: transition.durationDays)
            let newShare = ratio.formatted(.percent.precision(.fractionLength(0)))
            let oldShare = (1 - ratio).formatted(.percent.precision(.fractionLength(0)))
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Food transition · Day \(day + 1)")
            content.body = String(localized: "Mix \(newShare) \(transition.toFood) with \(oldShare) \(transition.fromFood) for \(petName).")
            content.sound = .default
            add(id: "transition-\(transition.id.uuidString)-\(day)", content: content, at: fireDate)
        }
    }

    func cancel(_ transition: DietTransition) {
        let ids = (0..<max(transition.durationDays, 30)).map { "transition-\(transition.id.uuidString)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Custom reminders

    func schedule(_ reminder: Reminder, petName: String) {
        let id = "reminder-\(reminder.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard !reminder.isCompleted else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.notes.isEmpty ? petName : "\(petName) · \(reminder.notes)"
        content.sound = .default

        let calendar = Calendar.current
        let set: Set<Calendar.Component>
        switch reminder.repeats {
        case .never: set = [.year, .month, .day, .hour, .minute]
        case .daily: set = [.hour, .minute]
        case .weekly: set = [.weekday, .hour, .minute]
        case .monthly: set = [.day, .hour, .minute]
        case .yearly: set = [.month, .day, .hour, .minute]
        }
        if reminder.repeats == .never, reminder.dueDate <= .now { return }
        let components = calendar.dateComponents(set, from: reminder.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeats != .never)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(_ reminder: Reminder) {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(reminder.id.uuidString)"])
    }

    // MARK: Symptom diary

    /// Daily evening nudge to photograph a symptom being tracked.
    func schedule(_ symptomCase: SymptomCase, petName: String) {
        let id = "symptom-\(symptomCase.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard !symptomCase.isResolved else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Symptom diary · \(petName)")
        content.body = String(localized: "Take today's photo of “\(symptomCase.title)” so your vet can see how it changes.")
        content.sound = .default
        var components = DateComponents()
        components.hour = 19
        components.minute = 0
        center.add(UNNotificationRequest(identifier: id, content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
    }

    func cancel(_ symptomCase: SymptomCase) {
        center.removePendingNotificationRequests(withIdentifiers: ["symptom-\(symptomCase.id.uuidString)"])
    }

    // MARK: Pet-wide

    func rescheduleAll(for pet: Pet) {
        for slot in pet.feedingSchedules ?? [] { schedule(slot, petName: pet.name) }
        for vaccination in pet.vaccinations ?? [] { schedule(vaccination, petName: pet.name) }
        for reminder in pet.reminders ?? [] { schedule(reminder, petName: pet.name) }
        if let transition = pet.activeTransition { schedule(transition, petName: pet.name) }
        for symptomCase in pet.openSymptomCases { schedule(symptomCase, petName: pet.name) }
    }

    func cancelAll(for pet: Pet) {
        for slot in pet.feedingSchedules ?? [] { cancel(slot) }
        for vaccination in pet.vaccinations ?? [] { cancel(vaccination) }
        for reminder in pet.reminders ?? [] { cancel(reminder) }
        for transition in pet.dietTransitions ?? [] { cancel(transition) }
        for symptomCase in pet.symptomCases ?? [] { cancel(symptomCase) }
    }

    private func add(id: String, content: UNNotificationContent, at date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

import Foundation
import SwiftData

// All properties have defaults and relationships are optional so the schema
// stays compatible with CloudKit sync, which is planned for a later release.

@Model
final class Pet {
    var id: UUID = UUID()
    var name: String = ""
    var speciesRaw: String = Species.dog.rawValue
    var breed: String = ""
    var birthDate: Date?
    var sexRaw: String = PetSex.unknown.rawValue
    var isNeutered: Bool = false
    var colorIndex: Int = 0
    @Attribute(.externalStorage) var photoData: Data?

    // Identification & emergency
    var microchipID: String = ""
    var bloodType: String = ""
    var allergies: String = ""
    var conditions: String = ""
    var emergencyNotes: String = ""

    // Veterinarian
    var vetClinic: String = ""
    var vetName: String = ""
    var vetPhone: String = ""
    var vetEmail: String = ""

    // Insurance
    var insuranceProvider: String = ""
    var insurancePolicy: String = ""

    var targetWeightKg: Double?

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Vaccination.pet) var vaccinations: [Vaccination]? = []
    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet) var weights: [WeightEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \VetVisit.pet) var visits: [VetVisit]? = []
    @Relationship(deleteRule: .cascade, inverse: \Expense.pet) var expenses: [Expense]? = []
    @Relationship(deleteRule: .cascade, inverse: \Medication.pet) var medications: [Medication]? = []
    @Relationship(deleteRule: .cascade, inverse: \FeedingSchedule.pet) var feedingSchedules: [FeedingSchedule]? = []
    @Relationship(deleteRule: .cascade, inverse: \FeedingLog.pet) var feedingLogs: [FeedingLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \DietTransition.pet) var dietTransitions: [DietTransition]? = []
    @Relationship(deleteRule: .cascade, inverse: \Reminder.pet) var reminders: [Reminder]? = []
    @Relationship(deleteRule: .cascade, inverse: \SymptomCase.pet) var symptomCases: [SymptomCase]? = []
    @Relationship(deleteRule: .cascade, inverse: \TravelPlan.pet) var travelPlans: [TravelPlan]? = []
    @Relationship(deleteRule: .cascade, inverse: \InsuranceClaim.pet) var insuranceClaims: [InsuranceClaim]? = []
    @Relationship(deleteRule: .cascade, inverse: \VetQuestion.pet) var vetQuestions: [VetQuestion]? = []

    /// Stable ID shared with family members' devices (household feeding sync).
    var householdPetID: String = ""

    init(name: String, species: Species) {
        self.name = name
        self.speciesRaw = species.rawValue
    }

    var species: Species {
        get { Species(rawValue: speciesRaw) ?? .other }
        set { speciesRaw = newValue.rawValue }
    }

    var sex: PetSex {
        get { PetSex(rawValue: sexRaw) ?? .unknown }
        set { sexRaw = newValue.rawValue }
    }

    var sortedWeights: [WeightEntry] {
        (weights ?? []).sorted { $0.date < $1.date }
    }

    var latestWeight: WeightEntry? { sortedWeights.last }

    var sortedVaccinations: [Vaccination] {
        (vaccinations ?? []).sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var sortedVisits: [VetVisit] {
        (visits ?? []).sorted { $0.date > $1.date }
    }

    var sortedExpenses: [Expense] {
        (expenses ?? []).sorted { $0.date > $1.date }
    }

    var sortedSchedules: [FeedingSchedule] {
        (feedingSchedules ?? []).sorted { $0.minutesFromMidnight < $1.minutesFromMidnight }
    }

    var activeMedications: [Medication] {
        (medications ?? []).filter(\.isActive)
    }

    var activeTransition: DietTransition? {
        (dietTransitions ?? []).first { $0.isActive && !$0.isComplete() }
    }

    var openReminders: [Reminder] {
        (reminders ?? []).filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }
    }

    var sortedSymptomCases: [SymptomCase] {
        (symptomCases ?? []).sorted { lhs, rhs in
            if lhs.isResolved != rhs.isResolved { return !lhs.isResolved }
            return lhs.lastUpdated > rhs.lastUpdated
        }
    }

    var openSymptomCases: [SymptomCase] { (symptomCases ?? []).filter { !$0.isResolved } }

    var sortedClaims: [InsuranceClaim] { (insuranceClaims ?? []).sorted { $0.createdAt > $1.createdAt } }

    var openQuestions: [VetQuestion] {
        (vetQuestions ?? []).filter { !$0.isAnswered }.sorted { $0.createdAt < $1.createdAt }
    }

    var upcomingTravelPlans: [TravelPlan] {
        (travelPlans ?? []).filter { $0.arrivalDate >= Calendar.current.startOfDay(for: .now) }.sorted { $0.arrivalDate < $1.arrivalDate }
    }

    /// Most recent vet visit, used as the baseline for visit preparation.
    var lastVisit: VetVisit? { sortedVisits.first { $0.date <= .now } }

    /// The most recent log of a kind within `window`, used to prevent double feeding.
    func recentLog(of kind: FeedingKind, within window: TimeInterval, now: Date = .now) -> FeedingLog? {
        (feedingLogs ?? [])
            .filter { $0.kind == kind && abs(now.timeIntervalSince($0.date)) < window }
            .max { $0.date < $1.date }
    }

    var vaccinesNeedingAttention: [Vaccination] {
        sortedVaccinations.filter { $0.status != .upToDate }
    }

    func logs(on day: Date, calendar: Calendar = .current) -> [FeedingLog] {
        (feedingLogs ?? [])
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }
    }

    var ageDescription: String? {
        guard let birthDate else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        let months = Calendar.current.dateComponents([.month], from: birthDate, to: .now).month ?? 0
        formatter.allowedUnits = months >= 24 ? [.year] : (months >= 1 ? [.year, .month] : [.weekOfMonth, .day])
        return formatter.string(from: birthDate, to: .now)
    }
}

@Model
final class Vaccination {
    var id: UUID = UUID()
    var name: String = ""
    var dateGiven: Date = Date()
    var nextDueDate: Date?
    var batchNumber: String = ""
    var administeredBy: String = ""
    var notes: String = ""
    var pet: Pet?

    init(name: String, dateGiven: Date = .now, nextDueDate: Date? = nil) {
        self.name = name
        self.dateGiven = dateGiven
        self.nextDueDate = nextDueDate
    }

    var status: VaccineStatus {
        guard let due = nextDueDate else { return .upToDate }
        let now = Date()
        if due < Calendar.current.startOfDay(for: now) { return .overdue }
        if due < now.addingTimeInterval(30 * 24 * 3600) { return .dueSoon }
        return .upToDate
    }
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kilograms: Double = 0
    var note: String = ""
    var pet: Pet?

    init(date: Date = .now, kilograms: Double, note: String = "") {
        self.date = date
        self.kilograms = kilograms
        self.note = note
    }
}

@Model
final class VetVisit {
    var id: UUID = UUID()
    var date: Date = Date()
    var clinic: String = ""
    var vetName: String = ""
    var reason: String = ""
    var diagnosis: String = ""
    var treatment: String = ""
    var notes: String = ""
    var cost: Double?
    var currencyCode: String = Formatting.defaultCurrencyCode
    var followUpDate: Date?
    var sourceRaw: String = VisitSource.manual.rawValue
    var rawText: String = ""
    @Attribute(.externalStorage) var attachment: Data?
    var pet: Pet?

    init(date: Date = .now) {
        self.date = date
    }

    var source: VisitSource {
        get { VisitSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !reason.isEmpty { return reason }
        if !diagnosis.isEmpty { return diagnosis }
        return String(localized: "Vet visit")
    }
}

@Model
final class Expense {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""
    var amount: Double = 0
    var currencyCode: String = Formatting.defaultCurrencyCode
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""
    var pet: Pet?

    init(title: String, amount: Double, category: ExpenseCategory, date: Date = .now) {
        self.title = title
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.date = date
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = ""
    var instructions: String = ""
    var startDate: Date = Date()
    var endDate: Date?
    var pet: Pet?

    init(name: String, dosage: String = "") {
        self.name = name
        self.dosage = dosage
    }

    var isActive: Bool {
        guard let endDate else { return true }
        return endDate >= Calendar.current.startOfDay(for: .now)
    }
}

@Model
final class FeedingSchedule {
    var id: UUID = UUID()
    var label: String = ""
    var kindRaw: String = FeedingKind.meal.rawValue
    var hour: Int = 8
    var minute: Int = 0
    var foodName: String = ""
    var portion: Double = 0
    var isEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var pet: Pet?

    init(label: String, kind: FeedingKind, hour: Int, minute: Int, portion: Double = 0) {
        self.label = label
        self.kindRaw = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.portion = portion
    }

    var kind: FeedingKind {
        get { FeedingKind(rawValue: kindRaw) ?? .meal }
        set { kindRaw = newValue.rawValue }
    }

    var minutesFromMidnight: Int { hour * 60 + minute }

    func time(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

@Model
final class FeedingLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = FeedingKind.meal.rawValue
    var amount: Double = 0
    var sourceRaw: String = LogSource.manual.rawValue
    var deviceName: String = ""
    /// Name of the family member who logged it ("Who fed?").
    var fedBy: String = ""
    /// Identifier of the event at the device vendor, used to avoid duplicate imports.
    var externalID: String = ""
    var scheduleID: UUID?
    var note: String = ""
    var pet: Pet?

    init(kind: FeedingKind, amount: Double = 0, date: Date = .now, source: LogSource = .manual, scheduleID: UUID? = nil) {
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.date = date
        self.sourceRaw = source.rawValue
        self.scheduleID = scheduleID
    }

    var kind: FeedingKind {
        get { FeedingKind(rawValue: kindRaw) ?? .meal }
        set { kindRaw = newValue.rawValue }
    }

    var source: LogSource {
        get { LogSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
}

@Model
final class DietTransition {
    var id: UUID = UUID()
    var fromFood: String = ""
    var toFood: String = ""
    var startDate: Date = Date()
    var durationDays: Int = 7
    var notes: String = ""
    var isActive: Bool = true
    var pet: Pet?

    init(fromFood: String, toFood: String, startDate: Date = .now, durationDays: Int = 7) {
        self.fromFood = fromFood
        self.toFood = toFood
        self.startDate = startDate
        self.durationDays = durationDays
    }

    /// Zero-based day index of the transition for the given date.
    func dayIndex(on date: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let day = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: day).day ?? 0
    }

    func newFoodRatio(on date: Date = .now, calendar: Calendar = .current) -> Double {
        DietTransitionPlan.newFoodRatio(dayIndex: dayIndex(on: date, calendar: calendar), durationDays: durationDays)
    }

    func isComplete(on date: Date = .now) -> Bool {
        dayIndex(on: date) >= durationDays
    }
}

/// Pure logic for the classic gradual food switch: 25% → 50% → 75% → 100% new food,
/// spread evenly across the transition period.
enum DietTransitionPlan {
    static func newFoodRatio(dayIndex: Int, durationDays: Int) -> Double {
        guard durationDays > 0 else { return 1 }
        if dayIndex < 0 { return 0 }
        if dayIndex >= durationDays { return 1 }
        let phase = min(3, Int(Double(dayIndex) / Double(durationDays) * 4))
        return Double(phase + 1) * 0.25
    }
}

@Model
final class Reminder {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date = Date()
    var repeatRaw: String = ReminderRepeat.never.rawValue
    var categoryRaw: String = ReminderCategory.other.rawValue
    var isCompleted: Bool = false
    var pet: Pet?

    init(title: String, dueDate: Date, category: ReminderCategory = .other, repeats: ReminderRepeat = .never) {
        self.title = title
        self.dueDate = dueDate
        self.categoryRaw = category.rawValue
        self.repeatRaw = repeats.rawValue
    }

    var repeats: ReminderRepeat {
        get { ReminderRepeat(rawValue: repeatRaw) ?? .never }
        set { repeatRaw = newValue.rawValue }
    }

    var category: ReminderCategory {
        get { ReminderCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Marks the reminder done. Repeating reminders roll forward to the next future occurrence instead.
    func complete(calendar: Calendar = .current) {
        guard let component = repeats.component else {
            isCompleted = true
            return
        }
        var next = dueDate
        repeat {
            next = calendar.date(byAdding: component, value: 1, to: next) ?? next.addingTimeInterval(86_400)
        } while next <= .now
        dueDate = next
    }
}

// MARK: - Symptom diary

/// Something the owner is watching over time, e.g. a rash on the left ear.
@Model
final class SymptomCase {
    var id: UUID = UUID()
    var title: String = ""
    var bodyArea: String = ""
    var startDate: Date = Date()
    var isResolved: Bool = false
    var resolvedDate: Date?
    var notes: String = ""
    var pet: Pet?
    @Relationship(deleteRule: .cascade, inverse: \SymptomEntry.symptomCase) var entries: [SymptomEntry]? = []

    init(title: String, bodyArea: String = "", startDate: Date = .now) {
        self.title = title
        self.bodyArea = bodyArea
        self.startDate = startDate
    }

    var sortedEntries: [SymptomEntry] {
        (entries ?? []).sorted { $0.date < $1.date }
    }

    var firstEntry: SymptomEntry? { sortedEntries.first }
    var latestEntry: SymptomEntry? { sortedEntries.last }
    var lastUpdated: Date { latestEntry?.date ?? startDate }

    /// Days since the case was first noticed (1-based).
    var dayCount: Int {
        (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate),
                                         to: Calendar.current.startOfDay(for: .now)).day ?? 0) + 1
    }

    /// Severity change from the first to the latest entry; negative means improving.
    var severityTrend: Int? {
        guard let first = firstEntry, let last = latestEntry, first.id != last.id else { return nil }
        return last.severity - first.severity
    }
}

@Model
final class SymptomEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// 1 (mild) … 5 (severe), as judged by the owner.
    var severity: Int = 2
    var note: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var symptomCase: SymptomCase?

    init(date: Date = .now, severity: Int = 2, note: String = "", photoData: Data? = nil) {
        self.date = date
        self.severity = severity
        self.note = note
        self.photoData = photoData
    }
}

// MARK: - Travel

@Model
final class TravelPlan {
    var id: UUID = UUID()
    /// ISO country code of the destination ("DE", "GB", "US" …).
    var destinationCode: String = "DE"
    var departureDate: Date = Date()
    var arrivalDate: Date = Date()
    var completedStepIDs: [String] = []
    var notes: String = ""
    var pet: Pet?

    init(destinationCode: String, departureDate: Date, arrivalDate: Date) {
        self.destinationCode = destinationCode
        self.departureDate = departureDate
        self.arrivalDate = arrivalDate
    }

    func isCompleted(_ stepID: String) -> Bool { completedStepIDs.contains(stepID) }

    func toggle(_ stepID: String) {
        if let index = completedStepIDs.firstIndex(of: stepID) {
            completedStepIDs.remove(at: index)
        } else {
            completedStepIDs.append(stepID)
        }
    }
}

// MARK: - Insurance

enum ClaimStatus: String, Codable, CaseIterable, Identifiable {
    case draft, submitted, approved, paid, denied
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .draft: "Draft"
        case .submitted: "Submitted"
        case .approved: "Approved"
        case .paid: "Paid"
        case .denied: "Denied"
        }
    }
}

@Model
final class InsuranceClaim {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify) var visit: VetVisit?
    var insurer: String = ""
    var policyNumber: String = ""
    var claimNumber: String = ""
    var statusRaw: String = ClaimStatus.draft.rawValue
    var amountClaimed: Double = 0
    var amountReimbursed: Double?
    var currencyCode: String = Formatting.defaultCurrencyCode
    var submittedDate: Date?
    var includeSymptomDiaries: Bool = true
    var notes: String = ""
    var pet: Pet?

    init(visit: VetVisit?) {
        self.visit = visit
    }

    var status: ClaimStatus {
        get { ClaimStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
}

// MARK: - Visit preparation

@Model
final class VetQuestion {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var isAnswered: Bool = false
    var answer: String = ""
    var pet: Pet?

    init(text: String) {
        self.text = text
    }
}

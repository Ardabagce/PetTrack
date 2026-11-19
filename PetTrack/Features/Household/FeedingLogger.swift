import SwiftData
import SwiftUI

/// Single entry point for logging feedings: attributes the log to the current family member,
/// shares it with the household and detects double feeding.
@MainActor
enum FeedingLogger {
    /// How close two logs of the same kind must be to count as a possible double feeding.
    static func doubleFeedWindow(for kind: FeedingKind) -> TimeInterval? {
        switch kind {
        case .meal: 2 * 3600
        case .water: 30 * 60
        case .treat: nil
        }
    }

    static func conflict(for pet: Pet, kind: FeedingKind, excludingSchedule scheduleID: UUID? = nil) -> FeedingLog? {
        guard let window = doubleFeedWindow(for: kind) else { return nil }
        guard let recent = pet.recentLog(of: kind, within: window) else { return nil }
        if let scheduleID, recent.scheduleID == scheduleID { return nil }
        return recent
    }

    @discardableResult
    static func log(_ kind: FeedingKind, for pet: Pet, amount: Double = 0, scheduleID: UUID? = nil,
                    source: LogSource = .manual, context: ModelContext) -> FeedingLog {
        let entry = FeedingLog(kind: kind, amount: amount, source: source, scheduleID: scheduleID)
        entry.fedBy = HouseholdService.shared.memberName
        entry.pet = pet
        context.insert(entry)
        try? context.save()
        HouseholdService.shared.publish(entry, context: context)
        return entry
    }

    static func conflictMessage(_ existing: FeedingLog, petName: String) -> String {
        let time = existing.date.formatted(date: .omitted, time: .shortened)
        let kind = String(localized: existing.kind.title).lowercased()
        if existing.fedBy.isEmpty || existing.fedBy == HouseholdService.shared.memberName {
            return String(localized: "A \(kind) was already logged for \(petName) at \(time).")
        }
        return String(localized: "\(existing.fedBy) already logged a \(kind) for \(petName) at \(time).")
    }
}

struct FeedingRequest: Identifiable {
    let id = UUID()
    let kind: FeedingKind
    let amount: Double
    let scheduleID: UUID?
    let existing: FeedingLog
}

extension View {
    /// Asks before logging a second meal or water refill shortly after someone else did.
    func doubleFeedAlert(_ request: Binding<FeedingRequest?>, petName: String, onConfirm: @escaping (FeedingRequest) -> Void) -> some View {
        alert(
            Text("Already fed?"),
            isPresented: Binding(get: { request.wrappedValue != nil }, set: { if !$0 { request.wrappedValue = nil } }),
            presenting: request.wrappedValue
        ) { pending in
            Button("Log anyway") { onConfirm(pending) }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(FeedingLogger.conflictMessage(pending.existing, petName: petName))
        }
    }
}

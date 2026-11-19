import AppIntents
import SwiftData

enum FeedingKindAppEnum: String, AppEnum {
    case meal, water, treat

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Feeding type"
    static let caseDisplayRepresentations: [FeedingKindAppEnum: DisplayRepresentation] = [
        .meal: "Meal",
        .water: "Water",
        .treat: "Treat",
    ]
}

/// "Hey Siri, log a meal in PetTrack" – also usable from Shortcuts and Home automations,
/// so smart feeders without an official API can still log events.
struct LogFeedingIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a feeding"
    static let description = IntentDescription("Records a meal, water refill or treat in PetTrack.")

    @Parameter(title: "Type", default: .meal)
    var kind: FeedingKindAppEnum

    @Parameter(title: "Pet name")
    var petName: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Persistence.container.mainContext
        let pets = try context.fetch(FetchDescriptor<Pet>(sortBy: [SortDescriptor(\.createdAt)]))
        let match = petName.flatMap { name in
            pets.first { $0.name.localizedCaseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame }
        }
        guard let pet = match ?? pets.first else {
            return .result(dialog: "Add a pet in PetTrack first.")
        }
        let feedingKind = FeedingKind(rawValue: kind.rawValue) ?? .meal
        if let existing = FeedingLogger.conflict(for: pet, kind: feedingKind) {
            // Don't double feed: tell the person instead of logging again.
            let message = FeedingLogger.conflictMessage(existing, petName: pet.name)
            return .result(dialog: "\(message)")
        }
        FeedingLogger.log(feedingKind, for: pet, source: .shortcut, context: context)
        return .result(dialog: "Logged for \(pet.name).")
    }
}

struct PetTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFeedingIntent(),
            phrases: [
                "Log a feeding in \(.applicationName)",
                "Log a meal in \(.applicationName)",
                "I fed my pet in \(.applicationName)",
            ],
            shortTitle: "Log feeding",
            systemImageName: "fork.knife"
        )
    }
}

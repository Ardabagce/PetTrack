import Foundation
import SwiftData

/// A feeding or drinking event reported by a connected device.
struct FeederEvent: Hashable {
    let externalID: String
    let date: Date
    let kind: FeedingKind
    let amount: Double
    let deviceName: String
}

enum FeederProviderStatus {
    case available, comingSoon
}

/// Adapter for a smart feeder / water fountain vendor.
///
/// None of the major vendors (PETLIBRO, Sure Petcare, PetSafe) publish an official public API today.
/// Each real provider will be added once a partner agreement or official API is in place;
/// see docs/SMART_FEEDERS.md for the integration plan.
protocol SmartFeederProvider {
    var id: String { get }
    var displayName: String { get }
    var deviceTypes: LocalizedStringResource { get }
    var symbol: String { get }
    var status: FeederProviderStatus { get }
    func fetchEvents(for pet: Pet, since: Date) async throws -> [FeederEvent]
}

/// Simulated feeder that mirrors the pet's feeding schedule. Lets users (and App Review) try the sync flow.
struct DemoFeederProvider: SmartFeederProvider {
    let id = "demo"
    let displayName = "PetTrack Demo Feeder"
    let deviceTypes: LocalizedStringResource = "Simulated feeder & fountain"
    let symbol = "sparkles"
    let status = FeederProviderStatus.available

    func fetchEvents(for pet: Pet, since: Date) async throws -> [FeederEvent] {
        let calendar = Calendar.current
        let now = Date()
        var events: [FeederEvent] = []
        var day = calendar.startOfDay(for: max(since, calendar.date(byAdding: .day, value: -2, to: now) ?? now))
        while day <= now {
            for slot in pet.sortedSchedules where slot.isEnabled {
                let time = slot.time(on: day).addingTimeInterval(Double.random(in: 0...240))
                guard time > since, time <= now else { continue }
                let dayKey = Int(day.timeIntervalSince1970 / 86_400)
                events.append(FeederEvent(
                    externalID: "demo-\(slot.id.uuidString)-\(dayKey)",
                    date: time,
                    kind: slot.kind,
                    amount: slot.portion,
                    deviceName: slot.kind == .water ? "Demo Fountain" : "Demo Feeder"
                ))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? now.addingTimeInterval(1)
        }
        return events
    }
}

/// Placeholder for vendors we plan to support.
struct UpcomingFeederProvider: SmartFeederProvider {
    let id: String
    let displayName: String
    let deviceTypes: LocalizedStringResource
    let symbol: String
    let status = FeederProviderStatus.comingSoon

    func fetchEvents(for pet: Pet, since: Date) async throws -> [FeederEvent] { [] }
}

enum FeederRegistry {
    static let providers: [any SmartFeederProvider] = [
        DemoFeederProvider(),
        UpcomingFeederProvider(id: "petlibro", displayName: "PETLIBRO", deviceTypes: "Feeders & fountains", symbol: "takeoutbag.and.cup.and.straw.fill"),
        UpcomingFeederProvider(id: "surepetcare", displayName: "Sure Petcare", deviceTypes: "SureFeed & Felaqua", symbol: "drop.circle.fill"),
        UpcomingFeederProvider(id: "petsafe", displayName: "PetSafe", deviceTypes: "Smart Feed", symbol: "fork.knife.circle.fill"),
    ]

    static func provider(id: String) -> (any SmartFeederProvider)? {
        providers.first { $0.id == id }
    }
}

@MainActor
enum FeederSyncService {
    /// Imports new device events as feeding logs, skipping ones already imported.
    @discardableResult
    static func sync(pet: Pet, context: ModelContext) async throws -> Int {
        guard let provider = FeederRegistry.provider(id: pet.feederProviderID), provider.status == .available else { return 0 }
        let since = pet.feederLastSync ?? Calendar.current.startOfDay(for: .now)
        let events = try await provider.fetchEvents(for: pet, since: since)
        let existing = Set((pet.feedingLogs ?? []).map(\.externalID).filter { !$0.isEmpty })
        var imported = 0
        for event in events where !existing.contains(event.externalID) {
            let log = FeedingLog(kind: event.kind, amount: event.amount, date: event.date, source: .device)
            log.deviceName = event.deviceName
            log.externalID = event.externalID
            log.pet = pet
            context.insert(log)
            imported += 1
        }
        pet.feederLastSync = .now
        try context.save()
        return imported
    }
}

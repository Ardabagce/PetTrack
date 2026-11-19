import CloudKit
import Foundation
import Observation
import SwiftData
import UIKit

/// Family sharing for feeding: everyone in the household sees who fed the pet and when.
///
/// The owner creates a CloudKit record zone ("Household") and shares the whole zone (CKShare).
/// It holds one `HouseholdPet` record per shared pet and a `FeedingEvent` record per meal,
/// water refill or treat. Members see the zone in their shared database; their app creates
/// a local copy of each pet (linked by `householdPetID`) and syncs feeding events both ways.
/// Health records stay private to the owner; the passport PDF covers the rest.
@Observable
@MainActor
final class HouseholdService {
    static let shared = HouseholdService()

    static let containerID = "iCloud.com.pettrack.app"
    static let zoneName = "Household"

    enum Role: String {
        case none, owner, member
    }

    enum Status: Equatable {
        case idle, syncing, failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var accountAvailable = false
    var role: Role {
        get { _ = roleVersion; return Role(rawValue: UserDefaults.standard.string(forKey: "household.role") ?? "") ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "household.role"); roleVersion += 1 }
    }
    /// Bumped so SwiftUI notices role changes stored in UserDefaults.
    private var roleVersion = 0

    /// Name shown next to feeding logs ("Fed by Alex").
    var memberName: String {
        get { _ = roleVersion; return UserDefaults.standard.string(forKey: "household.memberName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "household.memberName"); roleVersion += 1 }
    }

    var isEnabled: Bool { role != .none }

    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var ownerZoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName) }

    private var lastSync: Date? {
        get { UserDefaults.standard.object(forKey: "household.lastSync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "household.lastSync") }
    }

    // MARK: Account

    func refreshAccountStatus() async {
        accountAvailable = (try? await container.accountStatus()) == .available
    }

    // MARK: Owner: create share

    /// Creates the household zone, uploads the pets and returns a share to present in `UICloudSharingController`.
    func prepareShare(pets: [Pet], context: ModelContext) async throws -> (CKShare, CKContainer) {
        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneID: ownerZoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])

        for pet in pets where pet.householdPetID.isEmpty {
            pet.householdPetID = pet.id.uuidString
        }
        try? context.save()
        try await upload(pets: pets, database: database, zoneID: ownerZoneID)

        let share: CKShare
        if let existing = try? await database.record(for: CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: ownerZoneID)) as? CKShare {
            share = existing
        } else {
            share = CKShare(recordZoneID: ownerZoneID)
            share[CKShare.SystemFieldKey.title] = String(localized: "PetTrack household") as CKRecordValue
            share.publicPermission = .none
            _ = try await database.modifyRecords(saving: [share], deleting: [])
        }
        role = .owner
        return (share, container)
    }

    // MARK: Member: accept

    func accept(_ metadata: CKShare.Metadata) async {
        do {
            _ = try await container.accept(metadata)
            role = .member
            lastSync = nil
            await sync(context: Persistence.container.mainContext)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func leave() {
        role = .none
        lastSync = nil
    }

    // MARK: Sync

    /// Pushes local feeding logs that haven't been shared yet and pulls everyone else's.
    func sync(context: ModelContext) async {
        guard isEnabled else { return }
        status = .syncing
        do {
            let (database, zoneIDs) = try await householdZones()
            if role == .owner {
                // Pets added after the invitation are shared too.
                let pets = try context.fetch(FetchDescriptor<Pet>())
                for pet in pets where pet.householdPetID.isEmpty { pet.householdPetID = pet.id.uuidString }
                try await upload(pets: pets, database: database, zoneID: ownerZoneID)
            }
            for zoneID in zoneIDs {
                try await pull(database: database, zoneID: zoneID, context: context)
                try await pushPendingLogs(database: database, zoneID: zoneID, context: context)
            }
            lastSync = .now
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Uploads a single new feeding log right away so others see it within seconds.
    func publish(_ log: FeedingLog, context: ModelContext) {
        guard isEnabled, let pet = log.pet, !pet.householdPetID.isEmpty else { return }
        Task {
            guard let (database, zoneIDs) = try? await householdZones(), let zoneID = zoneIDs.first else { return }
            let record = feedingRecord(for: log, petID: pet.householdPetID, zoneID: zoneID)
            if (try? await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)) != nil {
                log.externalID = record.recordID.recordName
                try? context.save()
            }
        }
    }

    // MARK: Helpers

    private func householdZones() async throws -> (CKDatabase, [CKRecordZone.ID]) {
        switch role {
        case .owner:
            return (container.privateCloudDatabase, [ownerZoneID])
        case .member:
            let database = container.sharedCloudDatabase
            let zones = try await database.allRecordZones()
            return (database, zones.filter { $0.zoneID.zoneName == Self.zoneName }.map(\.zoneID))
        case .none:
            return (container.privateCloudDatabase, [])
        }
    }

    private func upload(pets: [Pet], database: CKDatabase, zoneID: CKRecordZone.ID) async throws {
        let records = pets.map { pet -> CKRecord in
            let record = CKRecord(recordType: "HouseholdPet", recordID: CKRecord.ID(recordName: "pet-\(pet.householdPetID)", zoneID: zoneID))
            record["petID"] = pet.householdPetID as CKRecordValue
            record["name"] = pet.name as CKRecordValue
            record["species"] = pet.speciesRaw as CKRecordValue
            record["schedule"] = (try? JSONEncoder().encode(pet.sortedSchedules.map(ScheduleDTO.init))).map { $0 as NSData }
            return record
        }
        _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
    }

    private func feedingRecord(for log: FeedingLog, petID: String, zoneID: CKRecordZone.ID) -> CKRecord {
        let name = log.externalID.hasPrefix("feed-") ? log.externalID : "feed-\(log.id.uuidString)"
        let record = CKRecord(recordType: "FeedingEvent", recordID: CKRecord.ID(recordName: name, zoneID: zoneID))
        record["petID"] = petID as CKRecordValue
        record["kind"] = log.kindRaw as CKRecordValue
        record["date"] = log.date as CKRecordValue
        record["amount"] = log.amount as CKRecordValue
        record["fedBy"] = log.fedBy as CKRecordValue
        return record
    }

    private func pushPendingLogs(database: CKDatabase, zoneID: CKRecordZone.ID, context: ModelContext) async throws {
        let pets = try context.fetch(FetchDescriptor<Pet>()).filter { !$0.householdPetID.isEmpty }
        var records: [CKRecord] = []
        var logsByRecord: [CKRecord.ID: FeedingLog] = [:]
        for pet in pets {
            for log in pet.feedingLogs ?? [] where log.externalID.isEmpty && log.source != .device {
                let record = feedingRecord(for: log, petID: pet.householdPetID, zoneID: zoneID)
                records.append(record)
                logsByRecord[record.recordID] = log
            }
        }
        guard !records.isEmpty else { return }
        let result = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
        for (id, outcome) in result.saveResults {
            if case .success = outcome { logsByRecord[id]?.externalID = id.recordName }
        }
        try context.save()
    }

    private func pull(database: CKDatabase, zoneID: CKRecordZone.ID, context: ModelContext) async throws {
        var pets = try context.fetch(FetchDescriptor<Pet>())

        // Pets (members create local copies).
        let petQuery = CKQuery(recordType: "HouseholdPet", predicate: NSPredicate(value: true))
        let petResults = try await database.records(matching: petQuery, inZoneWith: zoneID)
        for (_, result) in petResults.matchResults {
            guard case .success(let record) = result, let petID = record["petID"] as? String else { continue }
            if let local = pets.first(where: { $0.householdPetID == petID || $0.id.uuidString == petID }) {
                if role == .member { local.name = record["name"] as? String ?? local.name }
                local.householdPetID = petID
            } else if role == .member {
                let pet = Pet(name: record["name"] as? String ?? "", species: Species(rawValue: record["species"] as? String ?? "") ?? .dog)
                pet.householdPetID = petID
                if let data = record["schedule"] as? Data, let slots = try? JSONDecoder().decode([ScheduleDTO].self, from: data) {
                    for dto in slots {
                        let slot = FeedingSchedule(label: dto.label, kind: FeedingKind(rawValue: dto.kind) ?? .meal,
                                                   hour: dto.hour, minute: dto.minute, portion: dto.portion)
                        slot.foodName = dto.foodName
                        slot.pet = pet
                        context.insert(slot)
                    }
                }
                context.insert(pet)
                pets.append(pet)
            }
        }

        // Feeding events since the last sync.
        let since = lastSync?.addingTimeInterval(-3600) ?? Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let eventQuery = CKQuery(recordType: "FeedingEvent", predicate: NSPredicate(format: "date > %@", since as NSDate))
        let eventResults = try await database.records(matching: eventQuery, inZoneWith: zoneID, resultsLimit: 400)
        for (recordID, result) in eventResults.matchResults {
            guard case .success(let record) = result,
                  let petID = record["petID"] as? String,
                  let pet = pets.first(where: { $0.householdPetID == petID }) else { continue }
            let exists = (pet.feedingLogs ?? []).contains { $0.externalID == recordID.recordName }
            guard !exists else { continue }
            let log = FeedingLog(kind: FeedingKind(rawValue: record["kind"] as? String ?? "") ?? .meal,
                                 amount: record["amount"] as? Double ?? 0,
                                 date: record["date"] as? Date ?? .now,
                                 source: .household)
            log.fedBy = record["fedBy"] as? String ?? ""
            log.externalID = recordID.recordName
            log.pet = pet
            context.insert(log)
        }
        try context.save()
    }

    struct ScheduleDTO: Codable {
        var label: String
        var kind: String
        var hour: Int
        var minute: Int
        var portion: Double
        var foodName: String

        init(_ slot: FeedingSchedule) {
            label = slot.label
            kind = slot.kindRaw
            hour = slot.hour
            minute = slot.minute
            portion = slot.portion
            foodName = slot.foodName
        }
    }
}

// MARK: - Accepting invitations

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await HouseholdService.shared.accept(cloudKitShareMetadata)
        }
    }
}

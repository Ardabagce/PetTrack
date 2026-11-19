import Foundation
import SwiftData

@MainActor
enum Persistence {
    static let schema = Schema([
        Pet.self,
        Vaccination.self,
        WeightEntry.self,
        VetVisit.self,
        Expense.self,
        Medication.self,
        FeedingSchedule.self,
        FeedingLog.self,
        DietTransition.self,
        Reminder.self,
        SymptomCase.self,
        SymptomEntry.self,
        TravelPlan.self,
        InsuranceClaim.self,
        VetQuestion.self,
    ])

    /// Shared container used by the app and by App Intents (Siri / Shortcuts).
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }()

    static func previewContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        SampleData.insert(into: container.mainContext)
        return container
    }
}

@MainActor
enum SampleData {
    static func insert(into context: ModelContext) {
        let luna = Pet(name: "Luna", species: .dog)
        luna.breed = "Golden Retriever"
        luna.birthDate = Calendar.current.date(byAdding: .year, value: -3, to: .now)
        luna.sex = .female
        luna.isNeutered = true
        luna.microchipID = "985 112 004 556 781"
        luna.allergies = "Chicken protein"
        luna.vetClinic = "Riverside Animal Clinic"
        luna.vetName = "Dr. Emma Hart"
        luna.vetPhone = "+1 555 0142"
        luna.vetEmail = "care@riverside.vet"
        context.insert(luna)

        let weights: [(Int, Double)] = [(-150, 27.1), (-120, 27.6), (-90, 28.0), (-60, 28.4), (-30, 28.2), (-5, 28.9)]
        for (offset, kg) in weights {
            let entry = WeightEntry(date: Calendar.current.date(byAdding: .day, value: offset, to: .now)!, kilograms: kg)
            entry.pet = luna
            context.insert(entry)
        }

        let rabies = Vaccination(name: "Rabies", dateGiven: Calendar.current.date(byAdding: .month, value: -11, to: .now)!,
                                 nextDueDate: Calendar.current.date(byAdding: .day, value: 20, to: .now))
        rabies.pet = luna
        context.insert(rabies)
        let dhpp = Vaccination(name: "DHPP", dateGiven: Calendar.current.date(byAdding: .month, value: -4, to: .now)!,
                               nextDueDate: Calendar.current.date(byAdding: .month, value: 8, to: .now))
        dhpp.pet = luna
        context.insert(dhpp)

        for (label, kind, hour) in [("Breakfast", FeedingKind.meal, 8), ("Fresh water", .water, 9), ("Dinner", .meal, 18)] {
            let slot = FeedingSchedule(label: label, kind: kind, hour: hour, minute: 0, portion: kind == .water ? 500 : 180)
            slot.foodName = kind == .water ? "" : "Salmon & Rice"
            slot.pet = luna
            context.insert(slot)
        }

        let visit = VetVisit(date: Calendar.current.date(byAdding: .day, value: -12, to: .now)!)
        visit.clinic = "Riverside Animal Clinic"
        visit.vetName = "Dr. Emma Hart"
        visit.reason = "Annual check-up"
        visit.diagnosis = "Healthy, mild tartar"
        visit.treatment = "Dental chews, recheck in 6 months"
        visit.cost = 145
        visit.pet = luna
        context.insert(visit)

        let expense = Expense(title: "Annual check-up", amount: 145, category: .vet, date: visit.date)
        expense.pet = luna
        context.insert(expense)
    }
}

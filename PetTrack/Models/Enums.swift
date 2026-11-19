import Foundation

enum Species: String, Codable, CaseIterable, Identifiable {
    case dog, cat, rabbit, bird, other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .dog: "Dog"
        case .cat: "Cat"
        case .rabbit: "Rabbit"
        case .bird: "Bird"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .rabbit: "hare.fill"
        case .bird: "bird.fill"
        case .other: "pawprint.fill"
        }
    }

    /// Common core vaccines, used as quick suggestions in the vaccine editor.
    var suggestedVaccines: [String] {
        switch self {
        case .dog: ["Rabies", "DHPP", "Leptospirosis", "Bordetella", "Lyme", "Canine Influenza"]
        case .cat: ["Rabies", "FVRCP", "FeLV"]
        case .rabbit: ["RHDV1/RHDV2", "Myxomatosis"]
        case .bird: ["Polyomavirus"]
        case .other: ["Rabies"]
        }
    }
}

enum PetSex: String, Codable, CaseIterable, Identifiable {
    case female, male, unknown

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unknown: "Unknown"
        }
    }
}

enum FeedingKind: String, Codable, CaseIterable, Identifiable {
    case meal, water, treat

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .meal: "Meal"
        case .water: "Water"
        case .treat: "Treat"
        }
    }

    var symbol: String {
        switch self {
        case .meal: "fork.knife"
        case .water: "drop.fill"
        case .treat: "star.fill"
        }
    }

    /// Unit used for the portion amount: grams for food, millilitres for water.
    var unitSymbol: String {
        self == .water ? "ml" : "g"
    }
}

enum LogSource: String, Codable {
    case manual, device, shortcut, household
}

enum VisitSource: String, Codable {
    case manual, scan
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case vet, food, medication, insurance, grooming, supplies, other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .vet: "Vet"
        case .food: "Food"
        case .medication: "Medication"
        case .insurance: "Insurance"
        case .grooming: "Grooming"
        case .supplies: "Supplies"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .vet: "stethoscope"
        case .food: "fork.knife"
        case .medication: "pills.fill"
        case .insurance: "shield.lefthalf.filled"
        case .grooming: "scissors"
        case .supplies: "bag.fill"
        case .other: "ellipsis"
        }
    }
}

enum ReminderRepeat: String, Codable, CaseIterable, Identifiable {
    case never, daily, weekly, monthly, yearly

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var component: Calendar.Component? {
        switch self {
        case .never: nil
        case .daily: .day
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}

enum ReminderCategory: String, Codable, CaseIterable, Identifiable {
    case medication, parasite, grooming, vet, vaccine, other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .medication: "Medication"
        case .parasite: "Flea & tick"
        case .grooming: "Grooming"
        case .vet: "Vet visit"
        case .vaccine: "Vaccine"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .medication: "pills.fill"
        case .parasite: "ant.fill"
        case .grooming: "scissors"
        case .vet: "stethoscope"
        case .vaccine: "syringe.fill"
        case .other: "bell.fill"
        }
    }
}

enum VaccineStatus {
    case upToDate, dueSoon, overdue

    var title: LocalizedStringResource {
        switch self {
        case .upToDate: "Up to date"
        case .dueSoon: "Due soon"
        case .overdue: "Overdue"
        }
    }
}

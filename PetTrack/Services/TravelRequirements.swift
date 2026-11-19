import Foundation

/// Rules for travelling with a pet between the US and Europe.
///
/// Sources (verify before every trip, rules change):
/// - USDA APHIS Pet Travel: https://www.aphis.usda.gov/pet-travel
/// - EU non-commercial movement of pets, Regulation (EU) 576/2013 & 577/2013
/// - UK: https://www.gov.uk/bring-pet-to-great-britain
/// - CDC dog import rules (since 1 Aug 2024): https://www.cdc.gov/importation/dogs
enum TravelRequirements {
    struct Destination: Identifiable, Hashable {
        let code: String
        let flag: String
        /// Countries that require tapeworm (Echinococcus) treatment for dogs 1–5 days before arrival.
        let tapewormForDogs: Bool
        var id: String { code }

        var name: String {
            Locale.current.localizedString(forRegionCode: code) ?? code
        }

        var isUnitedStates: Bool { code == "US" }
        var isGreatBritain: Bool { code == "GB" }
    }

    static let destinations: [Destination] = [
        Destination(code: "US", flag: "🇺🇸", tapewormForDogs: false),
        Destination(code: "GB", flag: "🇬🇧", tapewormForDogs: true),
        Destination(code: "IE", flag: "🇮🇪", tapewormForDogs: true),
        Destination(code: "DE", flag: "🇩🇪", tapewormForDogs: false),
        Destination(code: "FR", flag: "🇫🇷", tapewormForDogs: false),
        Destination(code: "ES", flag: "🇪🇸", tapewormForDogs: false),
        Destination(code: "NL", flag: "🇳🇱", tapewormForDogs: false),
        Destination(code: "IT", flag: "🇮🇹", tapewormForDogs: false),
        Destination(code: "PT", flag: "🇵🇹", tapewormForDogs: false),
        Destination(code: "BE", flag: "🇧🇪", tapewormForDogs: false),
        Destination(code: "AT", flag: "🇦🇹", tapewormForDogs: false),
        Destination(code: "CH", flag: "🇨🇭", tapewormForDogs: false),
        Destination(code: "SE", flag: "🇸🇪", tapewormForDogs: false),
        Destination(code: "DK", flag: "🇩🇰", tapewormForDogs: false),
        Destination(code: "PL", flag: "🇵🇱", tapewormForDogs: false),
        Destination(code: "FI", flag: "🇫🇮", tapewormForDogs: true),
        Destination(code: "MT", flag: "🇲🇹", tapewormForDogs: true),
        Destination(code: "NO", flag: "🇳🇴", tapewormForDogs: true),
    ]

    static func destination(_ code: String) -> Destination {
        destinations.first { $0.code == code } ?? destinations[3]
    }

    enum StepState: Equatable {
        case done, ready, upcoming, overdue
    }

    struct Step: Identifiable, Equatable {
        let id: String
        let symbol: String
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        /// Earliest day the step can be done (nil = any time).
        let windowStart: Date?
        /// Deadline for the step.
        let deadline: Date?
        /// True when PetTrack can tell from the pet's records that the step is satisfied.
        let autoSatisfied: Bool
        let isRecommendation: Bool

        static func == (lhs: Step, rhs: Step) -> Bool { lhs.id == rhs.id }

        func state(completed: Bool, now: Date = .now) -> StepState {
            if completed || autoSatisfied { return .done }
            if let deadline, deadline < Calendar.current.startOfDay(for: now) { return .overdue }
            if let windowStart, windowStart > now { return .upcoming }
            return .ready
        }
    }

    /// Inputs taken from the pet's records.
    struct PetFacts {
        var species: Species
        var birthDate: Date?
        var microchipID: String
        var rabiesGiven: Date?
        var rabiesValidUntil: Date?

        var hasISOMicrochip: Bool {
            microchipID.filter(\.isNumber).count == 15
        }
    }

    static func facts(for pet: Pet) -> PetFacts {
        let rabies = (pet.vaccinations ?? [])
            .filter { $0.name.localizedCaseInsensitiveContains("rabies") || $0.name.localizedCaseInsensitiveContains("tollwut")
                || $0.name.localizedCaseInsensitiveContains("rage") || $0.name.localizedCaseInsensitiveContains("rabia")
                || $0.name.localizedCaseInsensitiveContains("hondsdolheid") }
            .max { $0.dateGiven < $1.dateGiven }
        return PetFacts(species: pet.species, birthDate: pet.birthDate, microchipID: pet.microchipID,
                        rabiesGiven: rabies?.dateGiven, rabiesValidUntil: rabies?.nextDueDate)
    }

    static func steps(to destination: Destination, arrival: Date, facts: PetFacts,
                      calendar: Calendar = .current) -> [Step] {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: arrival)) ?? arrival
        }
        return destination.isUnitedStates
            ? stepsToUS(arrival: arrival, facts: facts, day: day, calendar: calendar)
            : stepsToEurope(destination, arrival: arrival, facts: facts, day: day)
    }

    // MARK: US → Europe / UK

    private static func stepsToEurope(_ destination: Destination, arrival: Date, facts: PetFacts, day: (Int) -> Date) -> [Step] {
        var steps: [Step] = []

        steps.append(Step(
            id: "microchip", symbol: "dot.radiowaves.left.and.right",
            title: "ISO microchip",
            detail: "15-digit ISO 11784/11785 microchip, implanted on or before the day of the rabies vaccination.",
            windowStart: nil, deadline: day(-21), autoSatisfied: facts.hasISOMicrochip, isRecommendation: false))

        let rabiesValidAtArrival = (facts.rabiesValidUntil ?? .distantFuture) >= arrival
        let rabiesEarlyEnough = (facts.rabiesGiven ?? .distantFuture) <= day(-21)
        steps.append(Step(
            id: "rabies", symbol: "syringe.fill",
            title: "Rabies vaccination",
            detail: "Pet must be at least 12 weeks old. A first vaccination must be given at least 21 days before arrival; boosters given on time need no wait.",
            windowStart: nil, deadline: day(-21),
            autoSatisfied: rabiesValidAtArrival && rabiesEarlyEnough && facts.rabiesGiven != nil,
            isRecommendation: false))

        if destination.tapewormForDogs && facts.species == .dog {
            steps.append(Step(
                id: "tapeworm", symbol: "pills.fill",
                title: "Tapeworm treatment by a vet",
                detail: "Praziquantel treatment 24–120 hours (1–5 days) before arrival, recorded on the health certificate.",
                windowStart: day(-5), deadline: day(-1), autoSatisfied: false, isRecommendation: false))
        }

        steps.append(Step(
            id: "certificate", symbol: "doc.text.fill",
            title: destination.isGreatBritain ? "GB health certificate" : "EU health certificate",
            detail: "Issued by a USDA-accredited veterinarian within 10 days before arrival.",
            windowStart: day(-10), deadline: day(-2), autoSatisfied: false, isRecommendation: false))

        steps.append(Step(
            id: "endorsement", symbol: "checkmark.seal.fill",
            title: "USDA APHIS endorsement",
            detail: "Submit the certificate for endorsement (online via VEHCS) right after the vet visit and before departure.",
            windowStart: day(-10), deadline: day(-1), autoSatisfied: false, isRecommendation: false))

        steps.append(Step(
            id: "airline", symbol: "airplane",
            title: "Airline booking & travel crate",
            detail: "Book your pet's place early and check the airline's crate size and temperature rules.",
            windowStart: nil, deadline: day(-30), autoSatisfied: false, isRecommendation: true))

        return steps
    }

    // MARK: Europe → US

    private static func stepsToUS(arrival: Date, facts: PetFacts, day: (Int) -> Date, calendar: Calendar) -> [Step] {
        var steps: [Step] = []
        if facts.species == .dog {
            let ageOK: Bool = {
                guard let birth = facts.birthDate,
                      let sixMonths = calendar.date(byAdding: .month, value: 6, to: birth) else { return false }
                return sixMonths <= arrival
            }()
            steps.append(Step(
                id: "age", symbol: "birthday.cake.fill",
                title: "At least 6 months old",
                detail: "The CDC only allows dogs that are at least 6 months old on arrival.",
                windowStart: nil, deadline: nil, autoSatisfied: ageOK, isRecommendation: false))
            steps.append(Step(
                id: "microchip", symbol: "dot.radiowaves.left.and.right",
                title: "ISO microchip",
                detail: "An ISO-compatible microchip, implanted before any required rabies vaccination.",
                windowStart: nil, deadline: day(-14), autoSatisfied: facts.hasISOMicrochip, isRecommendation: false))
            steps.append(Step(
                id: "cdcForm", symbol: "list.clipboard.fill",
                title: "CDC Dog Import Form",
                detail: "Submit online 2–10 days before arrival and keep the receipt for the airline and border officer.",
                windowStart: day(-10), deadline: day(-2), autoSatisfied: false, isRecommendation: false))
            steps.append(Step(
                id: "rabies", symbol: "syringe.fill",
                title: "Rabies vaccination",
                detail: "Not required by the CDC for dogs from rabies-free or low-risk countries, but most states and airlines expect it.",
                windowStart: nil, deadline: day(-30),
                autoSatisfied: (facts.rabiesValidUntil ?? .distantPast) >= arrival, isRecommendation: true))
        } else {
            steps.append(Step(
                id: "rabies", symbol: "syringe.fill",
                title: "Rabies vaccination",
                detail: "No federal CDC rule for cats, but several states and most airlines require a current rabies vaccination.",
                windowStart: nil, deadline: day(-30),
                autoSatisfied: (facts.rabiesValidUntil ?? .distantPast) >= arrival, isRecommendation: true))
        }
        steps.append(Step(
            id: "fitToFly", symbol: "stethoscope",
            title: "Fit-to-fly check",
            detail: "Many airlines ask for a health certificate issued within 10 days of travel.",
            windowStart: day(-10), deadline: day(-1), autoSatisfied: false, isRecommendation: true))
        steps.append(Step(
            id: "airline", symbol: "airplane",
            title: "Airline booking & travel crate",
            detail: "Book your pet's place early and check the airline's crate size and temperature rules.",
            windowStart: nil, deadline: day(-30), autoSatisfied: false, isRecommendation: true))
        return steps
    }

    static func officialSource(for destination: Destination) -> URL {
        if destination.isUnitedStates { return URL(string: "https://www.cdc.gov/importation/dogs/")! }
        if destination.isGreatBritain { return URL(string: "https://www.gov.uk/bring-pet-to-great-britain")! }
        return URL(string: "https://www.aphis.usda.gov/pet-travel")!
    }
}

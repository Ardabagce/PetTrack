import Foundation

enum WeightUnitPreference: String, CaseIterable, Identifiable {
    case automatic, kilograms, pounds

    var id: String { rawValue }

    static let storageKey = "weightUnit"

    var title: LocalizedStringResource {
        switch self {
        case .automatic: "Automatic"
        case .kilograms: "Kilograms"
        case .pounds: "Pounds"
        }
    }

    var unit: UnitMass {
        switch self {
        case .kilograms: .kilograms
        case .pounds: .pounds
        case .automatic: Locale.current.measurementSystem == .us ? .pounds : .kilograms
        }
    }

    static var current: WeightUnitPreference {
        WeightUnitPreference(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .automatic
    }
}

enum Formatting {
    static var defaultCurrencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Currencies relevant for the US and European markets.
    static let supportedCurrencies = ["USD", "EUR", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN", "CZK", "CAD"]

    static func weight(_ kilograms: Double, unit: UnitMass = WeightUnitPreference.current.unit) -> String {
        Measurement(value: kilograms, unit: UnitMass.kilograms)
            .converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }

    static func weightValue(_ kilograms: Double, unit: UnitMass = WeightUnitPreference.current.unit) -> Double {
        Measurement(value: kilograms, unit: UnitMass.kilograms).converted(to: unit).value
    }

    static func kilograms(from value: Double, unit: UnitMass = WeightUnitPreference.current.unit) -> Double {
        Measurement(value: value, unit: unit).converted(to: .kilograms).value
    }

    static func unitSymbol(_ unit: UnitMass = WeightUnitPreference.current.unit) -> String {
        unit == .pounds ? "lb" : "kg"
    }

    static func currency(_ amount: Double, code: String) -> String {
        amount.formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }

    static func time(hour: Int, minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// Parses decimal input in either "12.5" or "12,5" notation.
    static func parseDecimal(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    static func decimalString(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

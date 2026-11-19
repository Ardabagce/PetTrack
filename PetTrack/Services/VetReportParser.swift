import Foundation

/// Structured data extracted from the text of a vet report or invoice.
struct ParsedVetReport: Equatable {
    var visitDate: Date?
    var clinic: String = ""
    var vetName: String = ""
    var reason: String = ""
    var diagnosis: String = ""
    var treatment: String = ""
    var weightKg: Double?
    var totalCost: Double?
    var currencyCode: String?
    var vaccines: [String] = []
    var followUpDate: Date?
    var rawText: String = ""

    var isEmpty: Bool {
        visitDate == nil && clinic.isEmpty && vetName.isEmpty && reason.isEmpty && diagnosis.isEmpty
            && treatment.isEmpty && weightKg == nil && totalCost == nil && vaccines.isEmpty
    }
}

/// Rule-based, on-device parser for vet reports in English, Spanish, German, French and Dutch.
/// It looks for labelled fields ("Diagnosis:", "Diagnose:", "Diagnóstico:" …), dates, weights,
/// totals and known vaccine names. Results are always shown to the user for review before saving.
enum VetReportParser {
    // MARK: Keywords (lowercased, accents kept as they appear on reports)

    static let reasonKeys = [
        "reason for visit", "chief complaint", "presenting complaint", "reason", "complaint",
        "motivo de consulta", "motivo de la visita", "motivo",
        "vorstellungsgrund", "grund des besuchs", "anlass", "grund",
        "motif de consultation", "motif de la visite", "motif",
        "reden van bezoek", "reden", "klacht",
    ]
    static let diagnosisKeys = [
        "diagnosis", "assessment", "findings",
        "diagnóstico", "diagnostico", "hallazgos",
        "diagnose", "befund", "befunde",
        "diagnostic", "conclusion",
        "bevindingen",
    ]
    static let treatmentKeys = [
        "treatment plan", "treatment", "therapy", "prescription", "plan", "medication",
        "tratamiento", "receta", "medicación",
        "behandlung", "therapie", "medikation",
        "traitement", "ordonnance", "prescription",
        "behandeling", "medicatie",
    ]
    static let vetKeys = [
        "attending veterinarian", "veterinarian", "attending", "doctor", "vet",
        "veterinario", "veterinaria",
        "tierärztin", "tierarzt", "behandelnder tierarzt",
        "vétérinaire", "veterinaire",
        "dierenarts",
    ]
    static let clinicKeys = [
        "clinic", "hospital", "practice",
        "clínica", "clinica", "hospital veterinario",
        "tierklinik", "praxis", "tierarztpraxis",
        "clinique", "cabinet vétérinaire",
        "dierenkliniek", "kliniek", "praktijk", "dierenartsenpraktijk",
    ]
    static let dateKeys = [
        "visit date", "date of visit", "date", "fecha", "datum", "date de visite", "bezoekdatum",
    ]
    static let followUpKeys = [
        "next appointment", "next visit", "follow-up", "follow up", "recheck",
        "próxima cita", "proxima cita", "revisión", "revision",
        "nächster termin", "wiedervorstellung", "kontrolle",
        "prochain rendez-vous", "prochaine visite", "contrôle",
        "volgende afspraak", "controle", "hercontrole",
    ]
    static let weightKeys = ["weight", "body weight", "peso", "gewicht", "körpergewicht", "poids"]
    static let totalKeys = [
        "total due", "amount due", "grand total", "total", "balance",
        "importe total", "total a pagar", "importe",
        "gesamtbetrag", "gesamt", "summe", "rechnungsbetrag", "betrag",
        "montant total", "montant", "total ttc",
        "totaal", "te betalen", "bedrag",
    ]
    static let clinicHints = ["clinic", "hospital", "veterinary", "animal", "vet ", "clínica", "veterinaria",
                              "tierarzt", "tierklinik", "clinique", "vétérinaire", "dierenarts", "dierenkliniek"]

    /// Canonical vaccine name → spellings that may appear on reports.
    static let vaccineAliases: [(String, [String])] = [
        ("Rabies", ["rabies", "tollwut", "rage", "rabia", "antirrábica", "antirrabica", "hondsdolheid"]),
        ("DHPP", ["dhpp", "dhlpp", "dappv", "dapp", "da2pp", "dhppi", "shp", "shpp", "shppi", "shppil", "chppi"]),
        ("Leptospirosis", ["leptospirosis", "leptospirose", "lepto"]),
        ("Bordetella", ["bordetella", "kennel cough", "zwingerhusten", "toux du chenil", "tos de las perreras", "kennelhoest"]),
        ("Parvovirus", ["parvovirus", "parvovirose", "parvo"]),
        ("Distemper", ["distemper", "staupe", "maladie de carré", "carré", "moquillo", "hondenziekte"]),
        ("Lyme", ["lyme", "borreliose", "borreliosis"]),
        ("Canine Influenza", ["canine influenza", "civ", "h3n2"]),
        ("FVRCP", ["fvrcp", "rcp", "katzenschnupfen", "coryza"]),
        ("FeLV", ["felv", "feline leukemia", "leukose", "leucose", "leucemia felina", "leukemie"]),
        ("Panleukopenia", ["panleukopenia", "panleukopenie", "katzenseuche", "typhus", "panleucopenia", "kattenziekte"]),
        ("RHDV", ["rhdv", "rhd2", "vhd", "rhd"]),
        ("Myxomatosis", ["myxomatosis", "myxomatose", "mixomatosis"]),
    ]

    // MARK: Parsing

    static func parse(_ text: String, locale: Locale = .current, now: Date = .now) -> ParsedVetReport {
        var report = ParsedVetReport(rawText: text)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let prefersMonthFirst = locale.region?.identifier == "US"

        report.reason = labeledValue(in: lines, keys: reasonKeys) ?? ""
        report.diagnosis = labeledValue(in: lines, keys: diagnosisKeys) ?? ""
        report.treatment = labeledValue(in: lines, keys: treatmentKeys) ?? ""
        report.vetName = labeledValue(in: lines, keys: vetKeys) ?? doctorName(in: lines) ?? ""
        // Clinic names often start with a keyword ("Tierarztpraxis am Park"), so only "Clinic: …" counts as a label.
        report.clinic = labeledValue(in: lines, keys: clinicKeys, requireColon: true) ?? clinicName(in: lines) ?? ""

        if let value = labeledValue(in: lines, keys: dateKeys) {
            report.visitDate = firstDate(in: value, monthFirst: prefersMonthFirst)
        }
        if let value = labeledValue(in: lines, keys: followUpKeys) {
            report.followUpDate = firstDate(in: value, monthFirst: prefersMonthFirst)
        }
        if report.visitDate == nil {
            report.visitDate = lines.lazy
                .compactMap { firstDate(in: $0, monthFirst: prefersMonthFirst) }
                .first { $0 <= now.addingTimeInterval(86_400) }
        }

        let weightLine = lines.first { line in weightKeys.contains { line.lowercased().contains($0) } }
        report.weightKg = (weightLine.flatMap(weight(in:))) ?? lines.lazy.compactMap(weight(in:)).first

        if let totalLine = lines.last(where: { line in
            let lower = line.lowercased()
            return totalKeys.contains { lower.contains($0) } && !lower.contains("subtotal") && amount(in: line) != nil
        }) {
            report.totalCost = amount(in: totalLine)
            report.currencyCode = currencyCode(in: totalLine) ?? currencyCode(in: text)
        }

        report.vaccines = vaccines(in: text)
        return report
    }

    // MARK: Field helpers

    /// Finds `Key: value` (or `Key - value`). If the value is empty, uses the following line.
    static func labeledValue(in lines: [String], keys: [String], requireColon: Bool = false) -> String? {
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            for key in keys where lower.hasPrefix(key) {
                let rest = line.dropFirst(key.count)
                if requireColon && !rest.trimmingCharacters(in: .whitespaces).hasPrefix(":") { continue }
                guard let first = rest.first else {
                    return next(after: index, in: lines)
                }
                // The key must be a whole word followed by a separator.
                guard first == ":" || first == "-" || first == "–" || first == " " || first == "\t" else { continue }
                let value = rest
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":-–\t ").union(.whitespaces))
                if value.isEmpty {
                    return next(after: index, in: lines)
                }
                // "Plan" or "Date" followed by unrelated words without a colon is too ambiguous.
                if first == " " && !rest.contains(":") && key.count < 6 { continue }
                return value
            }
        }
        return nil
    }

    private static func next(after index: Int, in lines: [String]) -> String? {
        let nextIndex = index + 1
        return nextIndex < lines.count ? lines[nextIndex] : nil
    }

    static func doctorName(in lines: [String]) -> String? {
        let pattern = #"\b(Dr|Dra|Drs|DVM|Dr\. med\. vet)\.?\s+[A-ZÀ-Ý][\p{L}'\-]+(\s+[A-ZÀ-Ý][\p{L}'\-]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range), let swiftRange = Range(match.range, in: line) {
                return String(line[swiftRange])
            }
        }
        return nil
    }

    static func clinicName(in lines: [String]) -> String? {
        lines.prefix(6).first { line in
            let lower = line.lowercased()
            return clinicHints.contains { lower.contains($0) } && line.count <= 60 && !lower.contains(":")
        }
    }

    // MARK: Numbers

    static func weight(in line: String) -> Double? {
        let pattern = #"(\d{1,3}(?:[.,]\d{1,2})?)\s*(kg|kgs|kilo|kilogram|kilogramm|kilogramos|lbs|lb|pounds)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let numberRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let value = Double(line[numberRange].replacingOccurrences(of: ",", with: ".")) else { return nil }
        let unit = line[unitRange].lowercased()
        let kg = unit.hasPrefix("lb") || unit == "pounds" ? value * 0.45359237 : value
        return (kg * 100).rounded() / 100
    }

    /// Returns the last monetary amount in a line, handling "1,234.56", "1.234,56" and "1 234,56".
    static func amount(in line: String) -> Double? {
        let pattern = #"(\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, range: range)
        guard let last = matches.last, let swiftRange = Range(last.range, in: line) else { return nil }
        return normalizeNumber(String(line[swiftRange]))
    }

    static func normalizeNumber(_ raw: String) -> Double? {
        var text = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: "")
        let lastDot = text.lastIndex(of: ".")
        let lastComma = text.lastIndex(of: ",")
        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            if dot > comma {
                text = text.replacingOccurrences(of: ",", with: "")
            } else {
                text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            }
        case let (nil, comma?):
            let decimals = text.distance(from: comma, to: text.endIndex) - 1
            text = decimals == 3 ? text.replacingOccurrences(of: ",", with: "") : text.replacingOccurrences(of: ",", with: ".")
        case let (dot?, nil):
            let decimals = text.distance(from: dot, to: text.endIndex) - 1
            let dots = text.filter { $0 == "." }.count
            if decimals == 3 || dots > 1 { text = text.replacingOccurrences(of: ".", with: "") }
        case (nil, nil):
            break
        }
        return Double(text)
    }

    static func currencyCode(in text: String) -> String? {
        let upper = text.uppercased()
        if text.contains("€") || upper.contains("EUR") { return "EUR" }
        if text.contains("£") || upper.contains("GBP") { return "GBP" }
        if upper.contains("CHF") { return "CHF" }
        if upper.contains("SEK") { return "SEK" }
        if upper.contains("DKK") { return "DKK" }
        if upper.contains("NOK") { return "NOK" }
        if text.contains("$") || upper.contains("USD") { return "USD" }
        return nil
    }

    // MARK: Dates

    static func firstDate(in text: String, monthFirst: Bool, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        // ISO yyyy-mm-dd
        if let match = firstMatch(#"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#, in: text),
           let date = makeDate(year: match[0], month: match[1], day: match[2], calendar: calendar) {
            return date
        }
        // dd.mm.yyyy, dd/mm/yyyy, mm/dd/yyyy, dd-mm-yyyy (2- or 4-digit year)
        if let match = firstMatch(#"\b(\d{1,2})[./\-](\d{1,2})[./\-](\d{2,4})\b"#, in: text) {
            var first = match[0], second = match[1]
            var year = match[2]
            if year < 100 { year += 2000 }
            let separatorIsDot = text.contains(".") && !text.contains("/")
            var monthFirstHere = monthFirst && !separatorIsDot
            if first > 12 { monthFirstHere = false }
            if second > 12 { monthFirstHere = true }
            if monthFirstHere { swap(&first, &second) }
            return makeDate(year: year, month: second, day: first, calendar: calendar)
        }
        // Textual dates such as "March 3, 2026" or "3 mars 2026".
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            return detector.firstMatch(in: text, range: range)?.date
        }
        return nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [Int]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var values: [Int] = []
        for index in 1..<match.numberOfRanges {
            guard let r = Range(match.range(at: index), in: text), let value = Int(text[r]) else { return nil }
            values.append(value)
        }
        return values
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day), (1990...2100).contains(year) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)
    }

    // MARK: Vaccines

    static func vaccines(in text: String) -> [String] {
        let lower = text.lowercased()
        var found: [String] = []
        for (canonical, aliases) in vaccineAliases {
            let hit = aliases.contains { alias in
                guard let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: alias))\\b") else { return false }
                return regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil
            }
            if hit { found.append(canonical) }
        }
        return found
    }
}

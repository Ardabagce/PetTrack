import XCTest
@testable import PetTrack

final class VetReportParserTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    func testEnglishInvoice() {
        let text = """
        Riverside Animal Clinic
        Dr. Emma Hart
        Date: 03/14/2026
        Reason for visit: Itchy ears
        Weight: 28.4 kg
        Diagnosis: Otitis externa
        Treatment: Ear drops twice daily for 10 days
        Rabies vaccine administered
        Next appointment: 04/14/2026
        Subtotal 120.00
        Total due $145.50
        """
        let report = VetReportParser.parse(text, locale: us)
        XCTAssertEqual(report.reason, "Itchy ears")
        XCTAssertEqual(report.diagnosis, "Otitis externa")
        XCTAssertEqual(report.treatment, "Ear drops twice daily for 10 days")
        XCTAssertEqual(report.weightKg, 28.4)
        XCTAssertEqual(report.totalCost, 145.5)
        XCTAssertEqual(report.currencyCode, "USD")
        XCTAssertEqual(report.vaccines, ["Rabies"])
        XCTAssertEqual(report.clinic, "Riverside Animal Clinic")
        XCTAssertEqual(report.vetName, "Dr. Emma Hart")
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.month, from: report.visitDate!), 3)
        XCTAssertNotNil(report.followUpDate)
    }

    func testGermanReport() {
        let text = """
        Tierarztpraxis am Park
        Datum: 14.03.2026
        Grund: Lahmheit hinten links
        Gewicht: 12,6 kg
        Diagnose: Zerrung
        Behandlung: Schonung, Schmerzmittel 5 Tage
        Tollwut, SHPPi geimpft
        Gesamtbetrag: 1.234,50 €
        """
        let report = VetReportParser.parse(text, locale: de)
        XCTAssertEqual(report.reason, "Lahmheit hinten links")
        XCTAssertEqual(report.diagnosis, "Zerrung")
        XCTAssertEqual(report.weightKg, 12.6)
        XCTAssertEqual(report.totalCost, 1234.5)
        XCTAssertEqual(report.currencyCode, "EUR")
        XCTAssertEqual(Set(report.vaccines), ["Rabies", "DHPP"])
        let calendar = Calendar(identifier: .gregorian)
        XCTAssertEqual(calendar.component(.day, from: report.visitDate!), 14)
        XCTAssertEqual(calendar.component(.month, from: report.visitDate!), 3)
    }

    func testPoundsAreConverted() {
        XCTAssertEqual(VetReportParser.weight(in: "Weight 62.5 lbs"), 28.35)
    }

    func testNumberNormalization() {
        XCTAssertEqual(VetReportParser.normalizeNumber("1,234.56"), 1234.56)
        XCTAssertEqual(VetReportParser.normalizeNumber("1.234,56"), 1234.56)
        XCTAssertEqual(VetReportParser.normalizeNumber("89,90"), 89.9)
        XCTAssertEqual(VetReportParser.normalizeNumber("1.200"), 1200)
    }
}

final class DietTransitionPlanTests: XCTestCase {
    func testSevenDayPlan() {
        let ratios = (0..<8).map { DietTransitionPlan.newFoodRatio(dayIndex: $0, durationDays: 7) }
        XCTAssertEqual(ratios, [0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1, 1])
    }

    func testBeforeStartIsOldFood() {
        XCTAssertEqual(DietTransitionPlan.newFoodRatio(dayIndex: -1, durationDays: 10), 0)
    }
}

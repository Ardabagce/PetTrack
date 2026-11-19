import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Runs on-device OCR on scanned pages and turns the text into a `ParsedVetReport`.
/// Nothing leaves the device: Vision does the OCR, and on iOS 26+ Apple's on-device
/// language model refines the extraction when it is available.
enum ReportScanService {
    static func analyze(images: [UIImage]) async throws -> ParsedVetReport {
        let text = try await recognizeText(in: images)
        var report = VetReportParser.parse(text)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let refined = await OnDeviceReportExtractor.refine(report, text: text) {
                report = refined
            }
        }
        #endif
        return report
    }

    static func recognizeText(in images: [UIImage]) async throws -> String {
        var pages: [String] = []
        for image in images {
            pages.append(try await recognizeText(in: image))
        }
        return pages.joined(separator: "\n\n")
    }

    private static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let preferred = ["en-US", "de-DE", "fr-FR", "es-ES", "nl-NL"]
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let languages = preferred.filter { supported.contains($0) }
            if !languages.isEmpty { request.recognitionLanguages = languages }
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct ExtractedVetReport {
    @Guide(description: "Name of the veterinary clinic or hospital, empty if unknown")
    var clinic: String
    @Guide(description: "Name of the attending veterinarian, empty if unknown")
    var veterinarian: String
    @Guide(description: "Short reason for the visit, in the report's language")
    var reason: String
    @Guide(description: "Diagnosis or findings, concise")
    var diagnosis: String
    @Guide(description: "Treatment, medication and recommendations, concise")
    var treatment: String
    @Guide(description: "Names of vaccines administered during this visit")
    var vaccines: [String]
}

@available(iOS 26.0, *)
enum OnDeviceReportExtractor {
    static func refine(_ report: ParsedVetReport, text: String) async -> ParsedVetReport? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: """
            You extract structured data from veterinary reports and invoices. \
            Only use information present in the text. Leave a field empty when it is not mentioned.
            """)
        do {
            let response = try await session.respond(
                to: "Veterinary report text:\n\(text.prefix(6000))",
                generating: ExtractedVetReport.self
            )
            let extracted = response.content
            var refined = report
            // Labelled values found by the rule-based parser take precedence; the model fills the gaps.
            if refined.clinic.isEmpty { refined.clinic = extracted.clinic }
            if refined.vetName.isEmpty { refined.vetName = extracted.veterinarian }
            if refined.reason.isEmpty { refined.reason = extracted.reason }
            if refined.diagnosis.isEmpty { refined.diagnosis = extracted.diagnosis }
            if refined.treatment.isEmpty { refined.treatment = extracted.treatment }
            for vaccine in extracted.vaccines where !refined.vaccines.contains(where: { $0.caseInsensitiveCompare(vaccine) == .orderedSame }) {
                refined.vaccines.append(vaccine)
            }
            return refined
        } catch {
            return nil
        }
    }
}
#endif

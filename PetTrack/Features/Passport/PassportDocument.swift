import SwiftUI
import UIKit

/// Printable health passport rendered to PDF (A4 width). Uses fixed light colours so it prints well.
struct PassportDocumentView: View {
    let pet: Pet

    private let ink = Color(hex: 0x17201C)
    private let muted = Color(hex: 0x5D6962)
    private let line = Color(hex: 0xE3DBCE)
    private let accent = Color(hex: 0xCF5F3B)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            HStack(alignment: .top, spacing: 18) {
                section("Identification") {
                    row("Species", String(localized: pet.species.title))
                    row("Breed", pet.breed)
                    row("Sex", String(localized: pet.sex.title) + (pet.isNeutered ? " · " + String(localized: "Neutered") : ""))
                    row("Born", pet.birthDate?.formatted(date: .long, time: .omitted) ?? "")
                    row("Microchip", pet.microchipID)
                    row("Latest weight", pet.latestWeight.map { "\(Formatting.weight($0.kilograms)) (\($0.date.formatted(date: .abbreviated, time: .omitted)))" } ?? "")
                }
                section("Emergency") {
                    row("Allergies", pet.allergies)
                    row("Conditions", pet.conditions)
                    row("Blood type", pet.bloodType)
                    row("Notes", pet.emergencyNotes)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                section("Veterinarian") {
                    row("Clinic", pet.vetClinic)
                    row("Veterinarian", pet.vetName)
                    row("Phone", pet.vetPhone)
                    row("Email", pet.vetEmail)
                }
                section("Insurance") {
                    row("Provider", pet.insuranceProvider)
                    row("Policy number", pet.insurancePolicy)
                }
            }

            section("Vaccinations") {
                table(headers: ["Vaccine", "Given", "Next due", "Batch"],
                      rows: pet.sortedVaccinations.map {
                          [$0.name,
                           $0.dateGiven.formatted(date: .abbreviated, time: .omitted),
                           $0.nextDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "—",
                           $0.batchNumber.isEmpty ? "—" : $0.batchNumber]
                      })
            }

            if !pet.activeMedications.isEmpty {
                section("Current medication") {
                    table(headers: ["Medication", "Dosage", "Instructions"],
                          rows: pet.activeMedications.map { [$0.name, $0.dosage, $0.instructions] })
                }
            }

            section("Vet visits") {
                if pet.sortedVisits.isEmpty {
                    Text("No visits recorded").font(.system(size: 10)).foregroundStyle(muted)
                }
                ForEach(pet.sortedVisits.prefix(12)) { visit in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(visit.displayTitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                            Spacer()
                            Text(visit.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(muted)
                        }
                        if !visit.diagnosis.isEmpty {
                            Text("\(Text("Diagnosis").bold()): \(visit.diagnosis)").font(.system(size: 10)).foregroundStyle(ink)
                        }
                        if !visit.treatment.isEmpty {
                            Text("\(Text("Treatment").bold()): \(visit.treatment)").font(.system(size: 10)).foregroundStyle(ink)
                        }
                        if !visit.clinic.isEmpty || !visit.vetName.isEmpty {
                            Text([visit.clinic, visit.vetName].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 9)).foregroundStyle(muted)
                        }
                    }
                    .padding(.vertical, 5)
                    Rectangle().fill(line).frame(height: 0.5)
                }
            }

            section("Weight history") {
                table(headers: ["Date", "Weight", "Note"],
                      rows: pet.sortedWeights.suffix(12).reversed().map {
                          [$0.date.formatted(date: .abbreviated, time: .omitted), Formatting.weight($0.kilograms), $0.note]
                      })
            }

            HStack {
                Text("Generated with PetTrack · \(Date.now.formatted(date: .long, time: .shortened))")
                Spacer()
                Text("Information provided by the owner. Please verify with original records.")
            }
            .font(.system(size: 8))
            .foregroundStyle(muted)
        }
        .padding(36)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if let data = pet.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Color(hex: 0xEBE4D8)
                        Image(systemName: pet.species.symbol).font(.system(size: 28)).foregroundStyle(muted)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("PET HEALTH PASSPORT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(accent)
                Text(pet.name)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
            }
            Spacer()
            Image(systemName: "pawprint.fill")
                .font(.system(size: 26))
                .foregroundStyle(accent)
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1.5) }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(muted)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func table(headers: [LocalizedStringKey], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 5)
            Rectangle().fill(line).frame(height: 0.5)
            if rows.isEmpty {
                Text("None recorded")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
                    .padding(.vertical, 5)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, cells in
                HStack(alignment: .top) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        Text(cell.isEmpty ? "—" : cell)
                            .font(.system(size: 10))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 5)
                Rectangle().fill(line).frame(height: 0.5)
            }
        }
    }
}

enum PDFRenderError: LocalizedError {
    case renderFailed
    var errorDescription: String? { String(localized: "The passport could not be rendered.") }
}

/// Renders a SwiftUI view (laid out at A4 width) into a single-page PDF in the temporary directory.
enum PDFRenderer {
    @MainActor
    static func render<Content: View>(_ view: Content, fileName: String) throws -> URL {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 595, height: nil)

        let safeName = fileName
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((safeName.isEmpty ? "PetTrack" : safeName) + ".pdf")
        try? FileManager.default.removeItem(at: url)

        var succeeded = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            succeeded = true
        }
        guard succeeded else { throw PDFRenderError.renderFailed }
        return url
    }
}

enum PassportExporter {
    @MainActor
    static func makePDF(for pet: Pet) throws -> URL {
        try PDFRenderer.render(PassportDocumentView(pet: pet), fileName: String(localized: "\(pet.name)-Health-Passport"))
    }
}

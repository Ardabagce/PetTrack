import SwiftData
import SwiftUI
import UIKit

extension ClaimStatus {
    var tint: Color {
        switch self {
        case .draft: Theme.inkTertiary
        case .submitted: Theme.sky
        case .approved: Theme.butter
        case .paid: Theme.sage
        case .denied: Theme.danger
        }
    }
}

/// Insurance claims list shown under Health → Costs.
struct ClaimsSection: View {
    let pet: Pet
    @State private var showEditor = false
    @State private var editing: InsuranceClaim?

    private var reimbursed: Double {
        pet.sortedClaims.compactMap(\.amountReimbursed).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Insurance claims", actionTitle: "New claim") { showEditor = true }
            if pet.sortedClaims.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bundle the invoice, vet report and symptom diary into one PDF for your insurer, then track the claim until it's paid.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                    Button { showEditor = true } label: { Label("Start a claim", systemImage: "doc.badge.plus") }
                        .buttonStyle(SoftButtonStyle(tint: Theme.sky))
                        .disabled(pet.sortedVisits.isEmpty)
                    if pet.sortedVisits.isEmpty {
                        Text("Add a vet visit first.").font(.caption).foregroundStyle(Theme.inkTertiary)
                    }
                }
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(pet.sortedClaims) { claim in
                        Button { editing = claim } label: { ClaimRow(claim: claim) }
                            .buttonStyle(.plain)
                    }
                    if reimbursed > 0 {
                        HStack {
                            Text("Reimbursed so far").font(.caption).foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text(Formatting.currency(reimbursed, code: pet.sortedClaims.first?.currencyCode ?? Formatting.defaultCurrencyCode))
                                .font(.numeric(14))
                                .foregroundStyle(Theme.sage)
                        }
                        .padding(.top, 8)
                    }
                }
                .card(padding: 16)
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { ClaimEditorView(pet: pet) }
        }
        .sheet(item: $editing) { claim in
            NavigationStack { ClaimEditorView(pet: pet, claim: claim) }
        }
    }
}

struct ClaimRow: View {
    let claim: InsuranceClaim

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "doc.text.fill", tint: claim.status.tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(claim.visit?.displayTitle ?? String(localized: "Vet visit"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text([claim.insurer, claim.visit?.date.formatted(date: .abbreviated, time: .omitted) ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatting.currency(claim.amountClaimed, code: claim.currencyCode))
                    .font(.numeric(14))
                    .foregroundStyle(Theme.ink)
                StatusPill(text: claim.status.title, tint: claim.status.tint)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct ClaimEditorView: View {
    let pet: Pet
    var claim: InsuranceClaim?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @State private var visitID: UUID?
    @State private var insurer = ""
    @State private var policy = ""
    @State private var claimNumber = ""
    @State private var status: ClaimStatus = .draft
    @State private var amount = ""
    @State private var reimbursed = ""
    @State private var currency = Formatting.defaultCurrencyCode
    @State private var includeSymptoms = true
    @State private var notes = ""
    @State private var exported: ExportedFile?
    @State private var paywall: PaywallContext?

    private var visit: VetVisit? { pet.sortedVisits.first { $0.id == visitID } }

    var body: some View {
        Form {
            Section("Visit") {
                Picker("Vet visit", selection: $visitID) {
                    ForEach(pet.sortedVisits) { visit in
                        Text("\(visit.date.formatted(date: .abbreviated, time: .omitted)) · \(visit.displayTitle)").tag(Optional(visit.id))
                    }
                }
                if let visit {
                    if visit.attachment != nil {
                        Label("Invoice / report photo attached", systemImage: "paperclip").font(.footnote).foregroundStyle(Theme.sage)
                    } else {
                        Label("No document photo on this visit. Scan the invoice to include it.", systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(Theme.butter)
                    }
                }
                Toggle("Include symptom diaries", isOn: $includeSymptoms)
            }
            Section("Insurer") {
                TextField("Insurance company", text: $insurer)
                TextField("Policy number", text: $policy)
                TextField("Claim number", text: $claimNumber)
            }
            Section("Amounts") {
                HStack {
                    Text("Claimed")
                    Spacer()
                    TextField("0", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                    Picker("Currency", selection: $currency) {
                        ForEach(Formatting.supportedCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().fixedSize()
                }
                HStack {
                    Text("Reimbursed")
                    Spacer()
                    TextField("Optional", text: $reimbursed).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                }
                Picker("Status", selection: $status) {
                    ForEach(ClaimStatus.allCases) { Text($0.title).tag($0) }
                }
            }
            Section {
                TextField("Notes", text: $notes, axis: .vertical)
            }
            Section {
                Button {
                    if store.isPremium { exportPack() } else { paywall = PaywallContext(feature: .claimPack) }
                } label: {
                    HStack {
                        Label("Create claim pack (PDF)", systemImage: "doc.richtext")
                        Spacer()
                        if !store.isPremium { PremiumBadge() }
                    }
                }
                .disabled(visit == nil)
            } footer: {
                Text("Includes the claim summary, visit details, the invoice photo and related symptom diary entries from the 30 days before the visit.")
            }
            if let claim {
                Section {
                    Button("Delete claim", role: .destructive) {
                        context.delete(claim)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(claim == nil ? Text("New claim") : Text("Edit claim"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { _ = save(); dismiss() }.fontWeight(.semibold).disabled(visit == nil)
            }
        }
        .onChange(of: visitID) { _, _ in
            if claim == nil, let visit {
                amount = Formatting.decimalString(visit.cost)
                currency = visit.currencyCode
            }
        }
        .onAppear(perform: load)
        .sheet(item: $exported) { ActivityView(items: [$0.url]).presentationDetents([.medium, .large]) }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private func load() {
        insurer = pet.insuranceProvider
        policy = pet.insurancePolicy
        if let claim {
            visitID = claim.visit?.id
            insurer = claim.insurer
            policy = claim.policyNumber
            claimNumber = claim.claimNumber
            status = claim.status
            amount = Formatting.decimalString(claim.amountClaimed)
            reimbursed = Formatting.decimalString(claim.amountReimbursed)
            currency = claim.currencyCode
            includeSymptoms = claim.includeSymptomDiaries
            notes = claim.notes
        } else {
            visitID = pet.sortedVisits.first?.id
        }
    }

    @discardableResult
    private func save() -> InsuranceClaim {
        let target = claim ?? InsuranceClaim(visit: visit)
        target.visit = visit
        target.insurer = insurer
        target.policyNumber = policy
        target.claimNumber = claimNumber
        if target.status != .submitted && status == .submitted { target.submittedDate = .now }
        target.status = status
        target.amountClaimed = Formatting.parseDecimal(amount) ?? 0
        target.amountReimbursed = Formatting.parseDecimal(reimbursed)
        target.currencyCode = currency
        target.includeSymptomDiaries = includeSymptoms
        target.notes = notes
        if claim == nil {
            target.pet = pet
            context.insert(target)
        }
        // Remember insurer details on the pet for next time.
        if pet.insuranceProvider.isEmpty { pet.insuranceProvider = insurer }
        if pet.insurancePolicy.isEmpty { pet.insurancePolicy = policy }
        try? context.save()
        return target
    }

    @MainActor
    private func exportPack() {
        let saved = save()
        guard let visit = saved.visit else { return }
        let name = String(localized: "\(pet.name)-Insurance-Claim-\(visit.date.formatted(.iso8601.year().month().day()))")
        if let url = try? PDFRenderer.render(ClaimPackDocument(claim: saved, visit: visit, pet: pet), fileName: name) {
            exported = ExportedFile(url: url)
        }
    }
}

/// Printable claim pack.
struct ClaimPackDocument: View {
    let claim: InsuranceClaim
    let visit: VetVisit
    let pet: Pet

    private let ink = Color(hex: 0x17201C)
    private let muted = Color(hex: 0x5D6962)
    private let accent = Color(hex: 0xCF5F3B)
    private let line = Color(hex: 0xE3DBCE)

    private struct EntryItem: Identifiable {
        let caseTitle: String
        let entry: SymptomEntry
        var id: UUID { entry.id }
    }

    private var symptomEntries: [EntryItem] {
        guard claim.includeSymptomDiaries else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -30, to: visit.date) ?? visit.date
        let end = visit.date.addingTimeInterval(86_400)
        return (pet.symptomCases ?? []).flatMap { symptomCase in
            symptomCase.sortedEntries
                .filter { $0.date >= start && $0.date <= end }
                .map { EntryItem(caseTitle: symptomCase.title, entry: $0) }
        }
        .sorted { $0.entry.date < $1.entry.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INSURANCE CLAIM PACK")
                    .font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(accent)
                Text(pet.name)
                    .font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1.5) }

            block("Claim") {
                row("Insurance company", claim.insurer)
                row("Policy number", claim.policyNumber)
                row("Claim number", claim.claimNumber)
                row("Amount claimed", Formatting.currency(claim.amountClaimed, code: claim.currencyCode))
            }
            block("Pet") {
                row("Species", String(localized: pet.species.title))
                row("Breed", pet.breed)
                row("Born", pet.birthDate?.formatted(date: .long, time: .omitted) ?? "")
                row("Microchip", pet.microchipID)
            }
            block("Treatment") {
                row("Date", visit.date.formatted(date: .long, time: .omitted))
                row("Clinic", visit.clinic)
                row("Veterinarian", visit.vetName)
                row("Reason", visit.reason)
                row("Diagnosis", visit.diagnosis)
                row("Treatment", visit.treatment)
                row("Invoice total", visit.cost.map { Formatting.currency($0, code: visit.currencyCode) } ?? "")
            }
            if !pet.conditions.isEmpty {
                block("Known conditions") { Text(pet.conditions).font(.system(size: 10)).foregroundStyle(ink) }
            }
            if !symptomEntries.isEmpty {
                block("Symptom history before the visit") {
                    ForEach(symptomEntries) { item in
                        let entry = item.entry
                        HStack(alignment: .top, spacing: 10) {
                            if let data = entry.photoData, let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 90, height: 68).clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.caseTitle) · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(ink)
                                Text(SeverityScale.title(entry.severity)).font(.system(size: 9)).foregroundStyle(muted)
                                if !entry.note.isEmpty { Text(entry.note).font(.system(size: 9)).foregroundStyle(ink) }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            if let data = visit.attachment, let image = UIImage(data: data) {
                block("Invoice / vet report") {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(line))
                }
            }
            Text("Generated with PetTrack · \(Date.now.formatted(date: .long, time: .shortened)). Please attach your insurer's claim form if required.")
                .font(.system(size: 8)).foregroundStyle(muted)
        }
        .padding(36)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func block<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1.5).textCase(.uppercase).foregroundStyle(accent)
            content()
        }
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.system(size: 10)).foregroundStyle(muted).frame(width: 120, alignment: .leading)
            Text(value.isEmpty ? "—" : value).font(.system(size: 10, weight: .medium)).foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

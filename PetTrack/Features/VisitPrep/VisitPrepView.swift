import SwiftData
import SwiftUI

/// Everything that happened since the last vet visit, condensed for the next appointment.
struct VisitPrepSummary {
    let since: Date
    let weightStart: Double?
    let weightNow: Double?
    let mealsPerDay: Double
    let plannedMealsPerDay: Int
    let waterPerDay: Double
    let symptomCases: [SymptomCase]
    let medications: [Medication]
    let vaccinesDue: [Vaccination]
    let questions: [VetQuestion]

    var weightChange: Double? {
        guard let weightStart, let weightNow else { return nil }
        return weightNow - weightStart
    }

    @MainActor
    static func build(for pet: Pet, now: Date = .now) -> VisitPrepSummary {
        let calendar = Calendar.current
        let since = pet.lastVisit?.date ?? calendar.date(byAdding: .month, value: -6, to: now) ?? now
        let weights = pet.sortedWeights
        let start = weights.last { $0.date <= since } ?? weights.first { $0.date >= since }
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let recentLogs = (pet.feedingLogs ?? []).filter { $0.date >= fourteenDaysAgo }
        let horizon = calendar.date(byAdding: .day, value: 60, to: now) ?? now
        return VisitPrepSummary(
            since: since,
            weightStart: start?.kilograms,
            weightNow: weights.last?.kilograms,
            mealsPerDay: Double(recentLogs.filter { $0.kind == .meal }.count) / 14,
            plannedMealsPerDay: pet.sortedSchedules.filter { $0.isEnabled && $0.kind == .meal }.count,
            waterPerDay: Double(recentLogs.filter { $0.kind == .water }.count) / 14,
            symptomCases: (pet.symptomCases ?? []).filter { $0.lastUpdated >= since }.sorted { $0.lastUpdated > $1.lastUpdated },
            medications: pet.activeMedications,
            vaccinesDue: (pet.vaccinations ?? []).filter { ($0.nextDueDate ?? .distantFuture) <= horizon },
            questions: pet.openQuestions
        )
    }
}

struct VisitPrepCard: View {
    let pet: Pet
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            HStack(spacing: 14) {
                IconBadge(symbol: "list.bullet.clipboard.fill", tint: Theme.sage, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Prepare for the next visit")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("A one-page summary of everything since the last check-up, plus your questions.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.inkTertiary)
            }
            .card()
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $show) {
            NavigationStack { VisitPrepView(pet: pet) }
        }
    }
}

struct VisitPrepView: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store
    @State private var newQuestion = ""
    @State private var exported: ExportedFile?
    @State private var paywall: PaywallContext?

    var body: some View {
        let summary = VisitPrepSummary.build(for: pet)
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Since \(summary.since.formatted(date: .long, time: .omitted))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkTertiary)
                    Text(pet.lastVisit.map { String(localized: "Last visit: \($0.displayTitle)") } ?? String(localized: "No previous visit recorded"))
                        .font(.headline)
                }
            }

            Section("Body & appetite") {
                prepRow("scalemass.fill", "Weight", value: weightText(summary), tint: Theme.sage)
                prepRow("fork.knife", "Meals per day (last 14 days)",
                        value: summary.mealsPerDay.formatted(.number.precision(.fractionLength(1)))
                            + (summary.plannedMealsPerDay > 0 ? " / \(summary.plannedMealsPerDay)" : ""),
                        tint: Theme.butter)
                prepRow("drop.fill", "Water refills per day", value: summary.waterPerDay.formatted(.number.precision(.fractionLength(1))), tint: Theme.sky)
            }

            Section("Symptoms") {
                if summary.symptomCases.isEmpty {
                    Text("No symptoms recorded since the last visit.").foregroundStyle(Theme.inkSecondary)
                }
                ForEach(summary.symptomCases) { symptomCase in
                    HStack(spacing: 12) {
                        SymptomThumbnail(data: symptomCase.latestEntry?.photoData, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symptomCase.title).font(.subheadline.weight(.semibold))
                            Text("Day \(symptomCase.dayCount) · \(symptomCase.sortedEntries.count) entries")
                                .font(.caption).foregroundStyle(Theme.inkSecondary)
                            if let trend = symptomCase.severityTrend { TrendLabel(trend: trend) }
                        }
                    }
                }
            }

            if !summary.medications.isEmpty || !summary.vaccinesDue.isEmpty {
                Section("Medication & vaccines") {
                    ForEach(summary.medications) { medication in
                        prepRow("pills.fill", LocalizedStringKey(medication.name), value: medication.dosage, tint: Theme.plum)
                    }
                    ForEach(summary.vaccinesDue) { vaccine in
                        prepRow("syringe.fill", LocalizedStringKey(vaccine.name),
                                value: vaccine.nextDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "",
                                tint: Theme.color(for: vaccine.status))
                    }
                }
            }

            Section {
                ForEach(summary.questions) { question in
                    HStack {
                        Button {
                            question.isAnswered = true
                            try? context.save()
                        } label: {
                            Image(systemName: "circle").foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Mark as asked"))
                        Text(question.text)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(summary.questions[index]) }
                    try? context.save()
                }
                HStack {
                    TextField("Add a question for the vet", text: $newQuestion)
                        .onSubmit(addQuestion)
                    Button("Add", action: addQuestion)
                        .disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Questions to ask")
            } footer: {
                Text("Write them down whenever they come to mind – it's easy to forget in the exam room.")
            }

            Section {
                Button {
                    if store.isPremium { export(summary) } else { paywall = PaywallContext(feature: .passportExport) }
                } label: {
                    HStack {
                        Label("Share summary with the vet (PDF)", systemImage: "square.and.arrow.up")
                        Spacer()
                        if !store.isPremium { PremiumBadge() }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .navigationTitle("Visit preparation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .sheet(item: $exported) { ActivityView(items: [$0.url]).presentationDetents([.medium, .large]) }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private func prepRow(_ symbol: String, _ title: LocalizedStringKey, value: String, tint: Color) -> some View {
        HStack {
            Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
            Spacer()
            Text(value.isEmpty ? "—" : value).font(.numeric(15)).foregroundStyle(Theme.ink)
        }
    }

    private func weightText(_ summary: VisitPrepSummary) -> String {
        guard let now = summary.weightNow else { return "" }
        guard let change = summary.weightChange, abs(change) >= 0.05 else { return Formatting.weight(now) }
        return "\(Formatting.weight(now)) (\(change > 0 ? "+" : "−")\(Formatting.weight(abs(change))))"
    }

    private func addQuestion() {
        let text = newQuestion.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let question = VetQuestion(text: text)
        question.pet = pet
        context.insert(question)
        try? context.save()
        newQuestion = ""
    }

    @MainActor
    private func export(_ summary: VisitPrepSummary) {
        let name = String(localized: "\(pet.name)-Visit-Summary")
        if let url = try? PDFRenderer.render(VisitPrepDocument(pet: pet, summary: summary, weight: weightText(summary)), fileName: name) {
            exported = ExportedFile(url: url)
        }
    }
}

struct VisitPrepDocument: View {
    let pet: Pet
    let summary: VisitPrepSummary
    let weight: String

    private let ink = Color(hex: 0x17201C)
    private let muted = Color(hex: 0x5D6962)
    private let accent = Color(hex: 0xCF5F3B)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRE-VISIT SUMMARY").font(.system(size: 9, weight: .bold)).tracking(2).foregroundStyle(accent)
                Text(pet.name).font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(ink)
                Text("Since \(summary.since.formatted(date: .long, time: .omitted))").font(.system(size: 11)).foregroundStyle(muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(ink).frame(height: 1.5) }

            group("Body & appetite") {
                line("Weight", weight)
                line("Meals per day (last 14 days)", summary.mealsPerDay.formatted(.number.precision(.fractionLength(1))))
                line("Water refills per day", summary.waterPerDay.formatted(.number.precision(.fractionLength(1))))
                line("Allergies", pet.allergies)
                line("Conditions", pet.conditions)
            }
            group("Symptoms") {
                if summary.symptomCases.isEmpty { Text("None recorded").font(.system(size: 10)).foregroundStyle(muted) }
                ForEach(summary.symptomCases) { symptomCase in
                    HStack(alignment: .top, spacing: 10) {
                        if let data = symptomCase.latestEntry?.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 80, height: 60).clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symptomCase.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(ink)
                            Text("\(symptomCase.bodyArea) · Since \(symptomCase.startDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 9)).foregroundStyle(muted)
                            if let last = symptomCase.latestEntry {
                                Text("\(String(localized: SeverityScale.title(last.severity))) · \(last.note)").font(.system(size: 9)).foregroundStyle(ink)
                            }
                        }
                    }
                }
            }
            group("Current medication") {
                if summary.medications.isEmpty { Text("None recorded").font(.system(size: 10)).foregroundStyle(muted) }
                ForEach(summary.medications) { medication in line(LocalizedStringKey(medication.name), medication.dosage) }
            }
            group("Questions") {
                if summary.questions.isEmpty { Text("None recorded").font(.system(size: 10)).foregroundStyle(muted) }
                ForEach(summary.questions) { question in
                    Text("☐  \(question.text)").font(.system(size: 11)).foregroundStyle(ink)
                }
            }
            Text("Generated with PetTrack · \(Date.now.formatted(date: .long, time: .shortened))").font(.system(size: 8)).foregroundStyle(muted)
        }
        .padding(36)
        .frame(width: 595, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(1.5).textCase(.uppercase).foregroundStyle(accent)
            content()
        }
    }

    private func line(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.system(size: 10)).foregroundStyle(muted).frame(width: 170, alignment: .leading)
            Text(value.isEmpty ? "—" : value).font(.system(size: 10, weight: .medium)).foregroundStyle(ink)
        }
    }
}

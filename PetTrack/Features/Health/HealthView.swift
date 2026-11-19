import Charts
import SwiftData
import SwiftUI

enum HealthSection: String, CaseIterable, Identifiable {
    case vaccines, journal, symptoms, weight, costs

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .vaccines: "Vaccines"
        case .journal: "Vet journal"
        case .symptoms: "Symptoms"
        case .weight: "Weight"
        case .costs: "Costs"
        }
    }
}

struct HealthView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""
    @State private var section: HealthSection = .vaccines

    private var pet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Health")
                        .font(.display(34))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 16)
                    PetSwitcher(pets: pets, selectedID: $selectedPetID)
                    SegmentedPills(selection: $section)
                        .guideTip(GuideTips.symptomDiary)

                    if let pet {
                        switch section {
                        case .vaccines: VaccinesSection(pet: pet)
                        case .journal: JournalSection(pet: pet)
                        case .symptoms: SymptomsSection(pet: pet)
                        case .weight: WeightSection(pet: pet)
                        case .costs: CostsSection(pet: pet)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .animation(.snappy, value: section)
            }
            .tabBarSafeArea()
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: VetVisit.self) { visit in
                VetVisitDetailView(visit: visit)
            }
            .navigationDestination(for: SymptomCase.self) { symptomCase in
                SymptomCaseDetailView(symptomCase: symptomCase)
            }
        }
    }
}

struct SegmentedPills<Value: Hashable & CaseIterable & Identifiable>: View where Value.AllCases: RandomAccessCollection, Value: SegmentTitled {
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Value.allCases) { value in
                    let isSelected = value == selection
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selection = value }
                    } label: {
                        Text(value.segmentTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Theme.canvas : Theme.inkSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    Capsule().fill(Theme.ink).matchedGeometryEffect(id: "pill", in: namespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Theme.surfaceMuted, in: Capsule())
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

protocol SegmentTitled {
    var segmentTitle: LocalizedStringResource { get }
}

extension HealthSection: SegmentTitled {
    var segmentTitle: LocalizedStringResource { title }
}

// MARK: - Vaccines

struct VaccinesSection: View {
    let pet: Pet
    @State private var showEditor = false
    @State private var editing: Vaccination?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Vaccinations", actionTitle: "Add") { showEditor = true }

            if (pet.vaccinations ?? []).isEmpty {
                EmptyStateView(symbol: "syringe", title: "No vaccines yet",
                               message: "Add past vaccinations and PetTrack will remind you before the next one is due.",
                               actionTitle: "Add vaccine") { showEditor = true }
                    .card()
            } else {
                VStack(spacing: 10) {
                    ForEach(pet.sortedVaccinations) { vaccine in
                        Button { editing = vaccine } label: { VaccineRow(vaccine: vaccine) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { VaccinationEditorView(pet: pet) }
        }
        .sheet(item: $editing) { vaccine in
            NavigationStack { VaccinationEditorView(pet: pet, vaccination: vaccine) }
        }
    }
}

struct VaccineRow: View {
    let vaccine: Vaccination

    var body: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: "syringe.fill", tint: Theme.color(for: vaccine.status))
            VStack(alignment: .leading, spacing: 3) {
                Text(vaccine.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Group {
                    if let due = vaccine.nextDueDate {
                        Text("Next: \(due.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("Given \(vaccine.dateGiven.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            StatusPill(text: vaccine.status.title, tint: Theme.color(for: vaccine.status))
        }
        .card(padding: 14)
    }
}

// MARK: - Journal

struct JournalSection: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @State private var showEditor = false
    @State private var showScanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                store.requirePremium(.reportScanning) { showScanner = true }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .frame(width: 48, height: 48)
                        .background(Theme.cream.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Scan a vet report")
                                .font(.headline)
                                .foregroundStyle(Theme.cream)
                            if !store.isPremium { PremiumBadge() }
                        }
                        Text("Photograph a report or invoice – we'll fill in the visit for you.")
                            .font(.caption)
                            .foregroundStyle(Theme.cream.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.cream.opacity(0.5))
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Theme.forest, Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
            }
            .buttonStyle(PressableStyle())
            .guideTip(GuideTips.scanReport)

            VisitPrepCard(pet: pet)

            SectionHeader(title: "Visits", actionTitle: "Add") { showEditor = true }

            if pet.sortedVisits.isEmpty {
                EmptyStateView(symbol: "stethoscope", title: "Your vet journal is empty",
                               message: "Record check-ups, diagnoses and treatments to build a complete medical history.")
                    .card()
            } else {
                VStack(spacing: 10) {
                    ForEach(pet.sortedVisits) { visit in
                        NavigationLink(value: visit) { VisitRow(visit: visit) }
                            .buttonStyle(PressableStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { VetVisitEditorView(pet: pet) }
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack { ScanReportView(pet: pet) }
        }
    }
}

struct VisitRow: View {
    let visit: VetVisit

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(visit.date, format: .dateTime.day())
                    .font(.numeric(20))
                    .foregroundStyle(Theme.ink)
                Text(visit.date, format: .dateTime.month(.abbreviated))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 48)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(visit.displayTitle)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if visit.source == .scan {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.caption)
                            .foregroundStyle(Theme.plum)
                    }
                }
                if !visit.diagnosis.isEmpty && visit.diagnosis != visit.displayTitle {
                    Text(visit.diagnosis)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if !visit.clinic.isEmpty { Text(visit.clinic).lineLimit(1) }
                    if let cost = visit.cost { Text(Formatting.currency(cost, code: visit.currencyCode)) }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.top, 6)
        }
        .card(padding: 14)
    }
}

struct VetVisitDetailView: View {
    let visit: VetVisit
    @State private var showEditor = false
    @State private var showOriginal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(LocalizedStringKey(visit.date.formatted(date: .complete, time: .omitted)))
                    Text(visit.displayTitle)
                        .font(.display(30))
                        .foregroundStyle(Theme.ink)
                    if !visit.clinic.isEmpty || !visit.vetName.isEmpty {
                        Text([visit.clinic, visit.vetName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    InfoRow(symbol: "text.bubble", title: "Reason", value: visit.reason)
                    InfoRow(symbol: "waveform.path.ecg", title: "Diagnosis", value: visit.diagnosis)
                    InfoRow(symbol: "cross.case", title: "Treatment", value: visit.treatment)
                    if !visit.notes.isEmpty { InfoRow(symbol: "note.text", title: "Notes", value: visit.notes) }
                    if let cost = visit.cost {
                        InfoRow(symbol: "creditcard", title: "Cost", value: Formatting.currency(cost, code: visit.currencyCode))
                    }
                    if let followUp = visit.followUpDate {
                        InfoRow(symbol: "calendar.badge.clock", title: "Follow-up",
                                value: followUp.formatted(date: .long, time: .omitted))
                    }
                }
                .card()

                if let data = visit.attachment, let image = UIImage(data: data) {
                    Button { showOriginal = true } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                            .overlay(alignment: .bottomLeading) {
                                Label("Original report", systemImage: "doc.text.image")
                                    .font(.caption.weight(.semibold))
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .padding(10)
                            }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(20)
        }
        .tabBarSafeArea()
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { showEditor = true }
        }
        .sheet(isPresented: $showEditor) {
            if let pet = visit.pet {
                NavigationStack { VetVisitEditorView(pet: pet, visit: visit) }
            }
        }
        .sheet(isPresented: $showOriginal) {
            if let data = visit.attachment, let image = UIImage(data: data) {
                NavigationStack {
                    ScrollView { Image(uiImage: image).resizable().scaledToFit() }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showOriginal = false } } }
                }
            }
        }
    }
}

// MARK: - Weight

struct WeightSection: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @State private var showEditor = false
    @State private var range: WeightRange = .sixMonths

    enum WeightRange: String, CaseIterable, Identifiable {
        case threeMonths, sixMonths, year, all
        var id: String { rawValue }
        var title: LocalizedStringResource {
            switch self {
            case .threeMonths: "3M"
            case .sixMonths: "6M"
            case .year: "1Y"
            case .all: "All"
            }
        }
        var startDate: Date {
            let calendar = Calendar.current
            switch self {
            case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
            case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: .now) ?? .distantPast
            case .year: return calendar.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            case .all: return .distantPast
            }
        }
    }

    private var entries: [WeightEntry] {
        pet.sortedWeights.filter { $0.date >= range.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weight", actionTitle: "Log") { showEditor = true }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pet.latestWeight.map { Formatting.weight($0.kilograms) } ?? "—")
                        .font(.display(34))
                        .foregroundStyle(Theme.ink)
                    if let target = pet.targetWeightKg {
                        Text("Target \(Formatting.weight(target))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                }
                Picker("Range", selection: $range) {
                    ForEach(WeightRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if entries.count >= 2 {
                    Chart {
                        ForEach(entries) { entry in
                            AreaMark(x: .value("Date", entry.date), y: .value("Weight", Formatting.weightValue(entry.kilograms)))
                                .foregroundStyle(LinearGradient(colors: [Theme.sage.opacity(0.28), Theme.sage.opacity(0)], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            LineMark(x: .value("Date", entry.date), y: .value("Weight", Formatting.weightValue(entry.kilograms)))
                                .foregroundStyle(Theme.sage)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", entry.date), y: .value("Weight", Formatting.weightValue(entry.kilograms)))
                                .foregroundStyle(Theme.sage)
                                .symbolSize(30)
                        }
                        if let target = pet.targetWeightKg {
                            RuleMark(y: .value("Target", Formatting.weightValue(target)))
                                .foregroundStyle(Theme.accent.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 190)
                } else {
                    Text("Add at least two entries to see a chart.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .card()

            if !pet.sortedWeights.isEmpty {
                VStack(spacing: 0) {
                    ForEach(pet.sortedWeights.reversed()) { entry in
                        HStack {
                            Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSecondary)
                            Spacer()
                            Text(Formatting.weight(entry.kilograms))
                                .font(.numeric(15))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 11)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(entry)
                                try? context.save()
                            }
                        }
                        Divider().overlay(Theme.hairline)
                    }
                }
                .card(padding: 16)
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { WeightEditorView(pet: pet) }
        }
    }
}

// MARK: - Costs

struct CostsSection: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @State private var showEditor = false
    @State private var editing: Expense?

    private var currency: String {
        pet.sortedExpenses.first?.currencyCode ?? Formatting.defaultCurrencyCode
    }

    private func total(since start: Date) -> Double {
        pet.sortedExpenses.filter { $0.date >= start && $0.currencyCode == currency }.reduce(0) { $0 + $1.amount }
    }

    private struct MonthlyTotal: Identifiable {
        let month: Date
        let category: ExpenseCategory
        let amount: Double
        var id: String { "\(month.timeIntervalSince1970)-\(category.rawValue)" }
    }

    private var monthly: [MonthlyTotal] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -5, to: calendar.startOfMonth(for: .now)) ?? .distantPast
        var buckets: [String: MonthlyTotal] = [:]
        for expense in pet.sortedExpenses where expense.date >= start && expense.currencyCode == currency {
            let month = calendar.startOfMonth(for: expense.date)
            let key = "\(month.timeIntervalSince1970)-\(expense.category.rawValue)"
            let current = buckets[key]?.amount ?? 0
            buckets[key] = MonthlyTotal(month: month, category: expense.category, amount: current + expense.amount)
        }
        return buckets.values.sorted { $0.month < $1.month }
    }

    var body: some View {
        let calendar = Calendar.current
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Costs", actionTitle: "Add") { showEditor = true }

            HStack(spacing: 10) {
                totalTile(title: "This month", amount: total(since: calendar.startOfMonth(for: .now)), tint: Theme.accent)
                totalTile(title: "This year", amount: total(since: calendar.date(from: calendar.dateComponents([.year], from: .now)) ?? .now), tint: Theme.sky)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow("Last 6 months")
                    Spacer()
                    if !store.isPremium { PremiumBadge() }
                }
                if monthly.isEmpty {
                    Text("Add expenses to see where your money goes.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    Chart(monthly) { item in
                        BarMark(x: .value("Month", item.month, unit: .month), y: .value("Amount", item.amount))
                            .foregroundStyle(by: .value("Category", String(localized: item.category.title)))
                            .cornerRadius(5)
                    }
                    .chartForegroundStyleScale(domain: ExpenseCategory.allCases.map { String(localized: $0.title) },
                                               range: ExpenseCategory.allCases.map { Theme.color(for: $0) })
                    .chartLegend(position: .bottom, spacing: 12)
                    .frame(height: 200)
                }
            }
            .card()
            .premiumLocked(!store.isPremium && !monthly.isEmpty, feature: .costInsights)

            if pet.sortedExpenses.isEmpty {
                EmptyStateView(symbol: "creditcard", title: "No expenses yet",
                               message: "Track vet bills, food, insurance and more.")
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(pet.sortedExpenses) { expense in
                        Button { editing = expense } label: {
                            HStack(spacing: 12) {
                                IconBadge(symbol: expense.category.symbol, tint: Theme.color(for: expense.category), size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.title.isEmpty ? String(localized: expense.category.title) : expense.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(expense.date, format: .dateTime.day().month(.abbreviated).year())
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                                Spacer()
                                Text(Formatting.currency(expense.amount, code: expense.currencyCode))
                                    .font(.numeric(15))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .card(padding: 16)
            }

            ClaimsSection(pet: pet)
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { ExpenseEditorView(pet: pet) }
        }
        .sheet(item: $editing) { expense in
            NavigationStack { ExpenseEditorView(pet: pet, expense: expense) }
        }
    }

    private func totalTile(title: LocalizedStringKey, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(title)
            Text(Formatting.currency(amount, code: currency))
                .font(.display(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Capsule().fill(tint).frame(width: 28, height: 4)
        }
        .card(padding: 16)
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

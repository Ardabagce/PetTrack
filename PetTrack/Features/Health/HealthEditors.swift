import SwiftData
import SwiftUI

// MARK: - Vaccination

struct VaccinationEditorView: View {
    let pet: Pet
    var vaccination: Vaccination?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var dateGiven = Date.now
    @State private var hasNextDue = true
    @State private var nextDue = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var batchNumber = ""
    @State private var administeredBy = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section {
                TextField("Vaccine name", text: $name)
                    .font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(pet.species.suggestedVaccines, id: \.self) { suggestion in
                        ChoiceChip(title: LocalizedStringResource(stringLiteral: suggestion), isSelected: name == suggestion) {
                            name = suggestion
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Dates") {
                DatePicker("Date given", selection: $dateGiven, displayedComponents: .date)
                Toggle("Booster due", isOn: $hasNextDue.animation())
                if hasNextDue {
                    DatePicker("Next due", selection: $nextDue, displayedComponents: .date)
                    HStack(spacing: 8) {
                        ForEach([1, 2, 3], id: \.self) { years in
                            Button("+\(years)y") {
                                nextDue = Calendar.current.date(byAdding: .year, value: years, to: dateGiven) ?? nextDue
                            }
                            .buttonStyle(SoftButtonStyle(tint: Theme.sky))
                        }
                    }
                }
            }

            Section("Details") {
                TextField("Batch / lot number", text: $batchNumber)
                TextField("Administered by", text: $administeredBy)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            if let vaccination {
                Section {
                    Button("Delete vaccine", role: .destructive) {
                        NotificationManager.shared.cancel(vaccination)
                        context.delete(vaccination)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(vaccination == nil ? Text("Add vaccine") : Text("Edit vaccine"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard let vaccination else { return }
            name = vaccination.name
            dateGiven = vaccination.dateGiven
            hasNextDue = vaccination.nextDueDate != nil
            nextDue = vaccination.nextDueDate ?? nextDue
            batchNumber = vaccination.batchNumber
            administeredBy = vaccination.administeredBy
            notes = vaccination.notes
        }
    }

    private func save() {
        let target = vaccination ?? Vaccination(name: name)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.dateGiven = dateGiven
        target.nextDueDate = hasNextDue ? nextDue : nil
        target.batchNumber = batchNumber
        target.administeredBy = administeredBy
        target.notes = notes
        if vaccination == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        NotificationManager.shared.schedule(target, petName: pet.name)
        dismiss()
    }
}

// MARK: - Weight

struct WeightEditorView: View {
    let pet: Pet

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnitPreference.storageKey) private var weightUnitRaw = WeightUnitPreference.automatic.rawValue
    @State private var value = ""
    @State private var date = Date.now
    @State private var note = ""
    @FocusState private var focused: Bool

    private var unit: UnitMass { (WeightUnitPreference(rawValue: weightUnitRaw) ?? .automatic).unit }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Spacer()
                    TextField("0.0", text: $value)
                        .font(.display(54))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                        .fixedSize()
                    Text(Formatting.unitSymbol(unit))
                        .font(.display(24))
                        .foregroundStyle(Theme.inkSecondary)
                    Spacer()
                }
                .padding(.vertical, 18)
                .listRowBackground(Color.clear)

                if let last = pet.latestWeight {
                    Text("Last: \(Formatting.weight(last.kilograms, unit: unit)) · \(last.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                DatePicker("Date", selection: $date, in: ...Date.now)
                TextField("Note", text: $note)
            }
        }
        .formCanvas()
        .navigationTitle("Log weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(Formatting.parseDecimal(value) == nil)
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        guard let number = Formatting.parseDecimal(value), number > 0 else { return }
        let entry = WeightEntry(date: date, kilograms: Formatting.kilograms(from: number, unit: unit), note: note)
        entry.pet = pet
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}

// MARK: - Expense

struct ExpenseEditorView: View {
    let pet: Pet
    var expense: Expense?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var currency = Formatting.defaultCurrencyCode
    @State private var category: ExpenseCategory = .vet
    @State private var date = Date.now
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    TextField("0", text: $amount)
                        .font(.display(44))
                        .keyboardType(.decimalPad)
                    Picker("Currency", selection: $currency) {
                        ForEach(Formatting.supportedCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                TextField("Description", text: $title)
            }
            Section("Category") {
                FlowLayout(spacing: 8) {
                    ForEach(ExpenseCategory.allCases) { item in
                        ChoiceChip(title: item.title, symbol: item.symbol, isSelected: category == item) { category = item }
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Note", text: $note, axis: .vertical)
            }
            if let expense {
                Section {
                    Button("Delete expense", role: .destructive) {
                        context.delete(expense)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(expense == nil ? Text("Add expense") : Text("Edit expense"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(Formatting.parseDecimal(amount) == nil)
            }
        }
        .onAppear {
            if let expense {
                title = expense.title
                amount = Formatting.decimalString(expense.amount)
                currency = expense.currencyCode
                category = expense.category
                date = expense.date
                note = expense.note
            } else if let last = pet.sortedExpenses.first {
                currency = last.currencyCode
            }
        }
    }

    private func save() {
        guard let value = Formatting.parseDecimal(amount) else { return }
        let target = expense ?? Expense(title: title, amount: value, category: category, date: date)
        target.title = title
        target.amount = value
        target.currencyCode = currency
        target.category = category
        target.date = date
        target.note = note
        if expense == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Vet visit

struct VetVisitEditorView: View {
    let pet: Pet
    var visit: VetVisit?
    /// Data pre-filled from a scanned report.
    var scanned: ParsedVetReport?
    var attachment: Data?
    /// Called after saving instead of `dismiss`, e.g. to close a multi-step scan flow.
    var onFinish: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnitPreference.storageKey) private var weightUnitRaw = WeightUnitPreference.automatic.rawValue

    @State private var date = Date.now
    @State private var clinic = ""
    @State private var vetName = ""
    @State private var reason = ""
    @State private var diagnosis = ""
    @State private var treatment = ""
    @State private var notes = ""
    @State private var cost = ""
    @State private var currency = Formatting.defaultCurrencyCode
    @State private var hasFollowUp = false
    @State private var followUp = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var weight = ""
    @State private var addToExpenses = true
    @State private var vaccines: [String] = []
    @State private var selectedVaccines: Set<String> = []
    @State private var showRawText = false
    @State private var loaded = false

    private var unit: UnitMass { (WeightUnitPreference(rawValue: weightUnitRaw) ?? .automatic).unit }
    private var isNew: Bool { visit == nil }

    var body: some View {
        Form {
            if scanned != nil {
                Section {
                    Label {
                        Text("We filled in what we could read. Please check every field before saving.")
                            .font(.footnote)
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Theme.plum)
                    }
                }
                .listRowBackground(Theme.plum.opacity(0.1))
            }

            Section("Visit") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Clinic", text: $clinic)
                TextField("Veterinarian", text: $vetName)
                TextField("Reason for visit", text: $reason, axis: .vertical)
            }

            Section("Medical") {
                TextField("Diagnosis", text: $diagnosis, axis: .vertical)
                TextField("Treatment & prescriptions", text: $treatment, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
                Toggle("Follow-up visit", isOn: $hasFollowUp.animation())
                if hasFollowUp {
                    DatePicker("Follow-up date", selection: $followUp, displayedComponents: .date)
                }
            }

            Section("Measurements & cost") {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Optional", text: $weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                    Text(Formatting.unitSymbol(unit)).foregroundStyle(Theme.inkSecondary)
                }
                HStack {
                    Text("Cost")
                    Spacer()
                    TextField("Optional", text: $cost)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 110)
                    Picker("Currency", selection: $currency) {
                        ForEach(Formatting.supportedCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if isNew {
                    Toggle("Add cost to expenses", isOn: $addToExpenses)
                }
            }

            if !vaccines.isEmpty {
                Section {
                    ForEach(vaccines, id: \.self) { vaccine in
                        Toggle(isOn: Binding(
                            get: { selectedVaccines.contains(vaccine) },
                            set: { if $0 { selectedVaccines.insert(vaccine) } else { selectedVaccines.remove(vaccine) } }
                        )) {
                            Label(vaccine, systemImage: "syringe.fill")
                        }
                    }
                } header: {
                    Text("Vaccines detected")
                } footer: {
                    Text("Selected vaccines are added to the vaccine schedule with a booster due in one year.")
                }
            }

            if let raw = scanned?.rawText, !raw.isEmpty {
                Section {
                    DisclosureGroup("Recognized text", isExpanded: $showRawText) {
                        Text(raw)
                            .font(.footnote.monospaced())
                            .foregroundStyle(Theme.inkSecondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if let visit {
                Section {
                    Button("Delete visit", role: .destructive) {
                        context.delete(visit)
                        try? context.save()
                        finish()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(isNew ? Text("New vet visit") : Text("Edit visit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onFinish == nil {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).fontWeight(.semibold)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        clinic = pet.vetClinic
        vetName = pet.vetName
        if let visit {
            date = visit.date
            clinic = visit.clinic
            vetName = visit.vetName
            reason = visit.reason
            diagnosis = visit.diagnosis
            treatment = visit.treatment
            notes = visit.notes
            cost = Formatting.decimalString(visit.cost)
            currency = visit.currencyCode
            hasFollowUp = visit.followUpDate != nil
            followUp = visit.followUpDate ?? followUp
        } else if let scanned {
            date = scanned.visitDate ?? .now
            if !scanned.clinic.isEmpty { clinic = scanned.clinic }
            if !scanned.vetName.isEmpty { vetName = scanned.vetName }
            reason = scanned.reason
            diagnosis = scanned.diagnosis
            treatment = scanned.treatment
            cost = Formatting.decimalString(scanned.totalCost)
            currency = scanned.currencyCode ?? currency
            if let followUpDate = scanned.followUpDate {
                hasFollowUp = true
                followUp = followUpDate
            }
            if let kg = scanned.weightKg {
                weight = Formatting.decimalString(Formatting.weightValue(kg, unit: unit))
            }
            vaccines = scanned.vaccines
            selectedVaccines = Set(scanned.vaccines)
        }
    }

    private func save() {
        let target = visit ?? VetVisit(date: date)
        target.date = date
        target.clinic = clinic
        target.vetName = vetName
        target.reason = reason
        target.diagnosis = diagnosis
        target.treatment = treatment
        target.notes = notes
        target.cost = Formatting.parseDecimal(cost)
        target.currencyCode = currency
        target.followUpDate = hasFollowUp ? followUp : nil

        if isNew {
            target.pet = pet
            if let scanned {
                target.source = .scan
                target.rawText = scanned.rawText
                target.attachment = attachment
            }
            context.insert(target)

            if let kg = Formatting.parseDecimal(weight).map({ Formatting.kilograms(from: $0, unit: unit) }), kg > 0 {
                let entry = WeightEntry(date: date, kilograms: kg, note: String(localized: "From vet visit"))
                entry.pet = pet
                context.insert(entry)
            }
            if addToExpenses, let amount = target.cost, amount > 0 {
                let expense = Expense(title: target.displayTitle, amount: amount, category: .vet, date: date)
                expense.currencyCode = currency
                expense.pet = pet
                context.insert(expense)
            }
            for name in vaccines where selectedVaccines.contains(name) {
                let vaccination = Vaccination(name: name, dateGiven: date,
                                              nextDueDate: Calendar.current.date(byAdding: .year, value: 1, to: date))
                vaccination.administeredBy = vetName
                vaccination.pet = pet
                context.insert(vaccination)
                NotificationManager.shared.schedule(vaccination, petName: pet.name)
            }
        }
        try? context.save()
        finish()
    }

    private func finish() {
        if let onFinish { onFinish() } else { dismiss() }
    }
}

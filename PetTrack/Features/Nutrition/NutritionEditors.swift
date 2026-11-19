import SwiftData
import SwiftUI

// MARK: - Feeding slot

struct FeedingScheduleEditorView: View {
    let pet: Pet
    var slot: FeedingSchedule?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: FeedingKind = .meal
    @State private var label = ""
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var foodName = ""
    @State private var portion = ""
    @State private var notify = true

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    ForEach(FeedingKind.allCases) { item in
                        ChoiceChip(title: item.title, symbol: item.symbol, isSelected: kind == item) { kind = item }
                    }
                }
                .padding(.vertical, 4)
                TextField("Label (e.g. Breakfast)", text: $label)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            }
            Section {
                if kind != .water {
                    TextField("Food", text: $foodName)
                }
                HStack {
                    Text("Portion")
                    Spacer()
                    TextField("Optional", text: $portion)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(kind.unitSymbol).foregroundStyle(Theme.inkSecondary)
                }
                Toggle("Daily notification", isOn: $notify)
            }
            if let slot {
                Section {
                    Button("Delete feeding time", role: .destructive) {
                        NotificationManager.shared.cancel(slot)
                        context.delete(slot)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(slot == nil ? Text("New feeding time") : Text("Edit feeding time"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
        }
        .onAppear {
            guard let slot else { return }
            kind = slot.kind
            label = slot.label
            time = slot.time(on: .now)
            foodName = slot.foodName
            portion = slot.portion > 0 ? Formatting.decimalString(slot.portion) : ""
            notify = slot.notificationsEnabled
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        let target = slot ?? FeedingSchedule(label: trimmed, kind: kind, hour: 8, minute: 0)
        target.label = trimmed.isEmpty ? String(localized: kind.title) : trimmed
        target.kind = kind
        target.hour = components.hour ?? 8
        target.minute = components.minute ?? 0
        target.foodName = kind == .water ? "" : foodName
        target.portion = Formatting.parseDecimal(portion) ?? 0
        target.notificationsEnabled = notify
        if slot == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.schedule(target, petName: pet.name)
        }
        dismiss()
    }
}

// MARK: - Diet transition

struct DietTransitionEditorView: View {
    let pet: Pet
    var transition: DietTransition?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var fromFood = ""
    @State private var toFood = ""
    @State private var startDate = Date.now
    @State private var duration = 7
    @State private var notes = ""

    private let durations = [7, 10, 14]

    var body: some View {
        Form {
            Section {
                TextField("Current food", text: $fromFood)
                TextField("New food", text: $toFood)
            } header: {
                Text("Foods")
            } footer: {
                Text("Vets usually recommend switching over 7–10 days. Take it slower for sensitive stomachs.")
            }
            Section("Plan") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                Picker("Duration", selection: $duration) {
                    ForEach(durations, id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Daily mix") {
                ForEach(phases, id: \.range) { phase in
                    HStack {
                        Text(phase.range)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 84, alignment: .leading)
                        MixBar(newRatio: phase.ratio, newFood: toFood.isEmpty ? String(localized: "New") : toFood,
                               oldFood: fromFood.isEmpty ? String(localized: "Current") : fromFood)
                    }
                    .padding(.vertical, 4)
                }
            }
            Section {
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if let transition {
                Section {
                    Button("End transition", role: .destructive) {
                        transition.isActive = false
                        NotificationManager.shared.cancel(transition)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle("Food transition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(fromFood.isEmpty || toFood.isEmpty)
            }
        }
        .onAppear {
            if let transition {
                fromFood = transition.fromFood
                toFood = transition.toFood
                startDate = transition.startDate
                duration = transition.durationDays
                notes = transition.notes
            } else if let food = pet.sortedSchedules.first(where: { !$0.foodName.isEmpty })?.foodName {
                fromFood = food
            }
        }
    }

    private struct Phase {
        let range: String
        let ratio: Double
    }

    /// Groups consecutive days with the same ratio, e.g. "Day 1–2: 25%".
    private var phases: [Phase] {
        var result: [Phase] = []
        var start = 0
        for day in 0...duration {
            let isEnd = day == duration
            let ratio = DietTransitionPlan.newFoodRatio(dayIndex: start, durationDays: duration)
            if isEnd || DietTransitionPlan.newFoodRatio(dayIndex: day, durationDays: duration) != ratio {
                let range = start == day - 1
                    ? String(localized: "Day \(start + 1)")
                    : String(localized: "Day \(start + 1)–\(day)")
                result.append(Phase(range: range, ratio: ratio))
                start = day
            }
        }
        return result
    }

    private func save() {
        for other in pet.dietTransitions ?? [] where other.id != transition?.id && other.isActive {
            other.isActive = false
            NotificationManager.shared.cancel(other)
        }
        let target = transition ?? DietTransition(fromFood: fromFood, toFood: toFood)
        target.fromFood = fromFood
        target.toFood = toFood
        target.startDate = startDate
        target.durationDays = duration
        target.notes = notes
        target.isActive = true
        if transition == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.schedule(target, petName: pet.name)
        }
        dismiss()
    }
}

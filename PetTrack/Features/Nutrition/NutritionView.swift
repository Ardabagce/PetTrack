import SwiftData
import SwiftUI

struct NutritionView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""

    private var pet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Nutrition")
                        .font(.display(34))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 16)
                    PetSwitcher(pets: pets, selectedID: $selectedPetID)
                    if let pet {
                        IntakeCard(pet: pet)
                        ScheduleSection(pet: pet)
                        TransitionSection(pet: pet)
                        FoodSafetyCard()
                        RecentLogsSection(pet: pet)
                    }
                }
                .padding(.horizontal, 20)
            }
            .tabBarSafeArea()
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Intake

struct IntakeCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @State private var lastLogged: FeedingKind?
    @State private var pendingFeeding: FeedingRequest?

    var body: some View {
        let logs = pet.logs(on: .now)
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow("Today")
            HStack(spacing: 10) {
                ForEach(FeedingKind.allCases) { kind in
                    let count = logs.filter { $0.kind == kind }.count
                    let planned = pet.sortedSchedules.filter { $0.isEnabled && $0.kind == kind }.count
                    Button { log(kind) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: kind.symbol)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: lastLogged == kind ? "checkmark" : "plus")
                                    .font(.caption.weight(.bold))
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .foregroundStyle(Theme.color(for: kind))
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(count)")
                                    .font(.display(28))
                                    .foregroundStyle(Theme.ink)
                                if planned > 0 && kind != .treat {
                                    Text("/\(planned)")
                                        .font(.numeric(14))
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                            }
                            Text(kind.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.color(for: kind).opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .sensoryFeedback(.success, trigger: lastLogged)
        }
        .card()
        .doubleFeedAlert($pendingFeeding, petName: pet.name) { commit($0.kind) }
    }

    private func log(_ kind: FeedingKind) {
        if let existing = FeedingLogger.conflict(for: pet, kind: kind) {
            pendingFeeding = FeedingRequest(kind: kind, amount: 0, scheduleID: nil, existing: existing)
            return
        }
        commit(kind)
    }

    private func commit(_ kind: FeedingKind) {
        FeedingLogger.log(kind, for: pet, context: context)
        withAnimation { lastLogged = kind }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if lastLogged == kind { lastLogged = nil } }
        }
    }
}

// MARK: - Schedule

struct ScheduleSection: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @State private var showEditor = false
    @State private var editing: FeedingSchedule?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Feeding schedule", actionTitle: "Add") {
                if pet.sortedSchedules.count >= FreeTier.maxFeedingSlots && !store.isPremium {
                    store.presentPaywall(.unlimitedReminders)
                } else {
                    showEditor = true
                }
            }
            if pet.sortedSchedules.isEmpty {
                EmptyStateView(symbol: "clock", title: "No feeding times",
                               message: "Set meal and water times and we'll remind you every day.")
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(pet.sortedSchedules) { slot in
                        ScheduleRow(slot: slot, petName: pet.name) { editing = slot }
                        if slot.id != pet.sortedSchedules.last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 56)
                        }
                    }
                }
                .card(padding: 14)
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { FeedingScheduleEditorView(pet: pet) }
        }
        .sheet(item: $editing) { slot in
            NavigationStack { FeedingScheduleEditorView(pet: pet, slot: slot) }
        }
    }
}

struct ScheduleRow: View {
    @Bindable var slot: FeedingSchedule
    let petName: String
    var onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    IconBadge(symbol: slot.kind.symbol, tint: Theme.color(for: slot.kind), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(Formatting.time(hour: slot.hour, minute: slot.minute))
                        .font(.numeric(16))
                        .foregroundStyle(slot.isEnabled ? Theme.ink : Theme.inkTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: $slot.isEnabled)
                .labelsHidden()
                .tint(Theme.sage)
                .onChange(of: slot.isEnabled) {
                    NotificationManager.shared.schedule(slot, petName: petName)
                }
        }
        .padding(.vertical, 8)
    }

    private var detail: String {
        var parts: [String] = []
        if !slot.foodName.isEmpty { parts.append(slot.foodName) }
        if slot.portion > 0 { parts.append("\(Formatting.decimalString(slot.portion)) \(slot.kind.unitSymbol)") }
        if parts.isEmpty { parts.append(String(localized: slot.kind.title)) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Transition

struct TransitionSection: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let transition = pet.activeTransition {
                SectionHeader(title: "Food transition", actionTitle: "Edit") { showEditor = true }
                TransitionTimeline(transition: transition)
                    .card()
            } else {
                Button {
                    store.requirePremium(.dietTransition) { showEditor = true }
                } label: {
                    HStack(spacing: 14) {
                        IconBadge(symbol: "arrow.triangle.swap", tint: Theme.butter, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Switching food?")
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                if !store.isPremium { PremiumBadge() }
                            }
                            Text("Get a gentle day-by-day mixing plan to avoid upset tummies.")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    .card()
                }
                .buttonStyle(PressableStyle())
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { DietTransitionEditorView(pet: pet, transition: pet.activeTransition) }
        }
    }
}

struct TransitionTimeline: View {
    let transition: DietTransition

    var body: some View {
        let today = transition.dayIndex()
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(transition.fromFood) → \(transition.toFood)")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Day \(min(today + 1, transition.durationDays)) of \(transition.durationDays)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
            }
            MixBar(newRatio: transition.newFoodRatio(), newFood: transition.toFood, oldFood: transition.fromFood)
            HStack(spacing: 4) {
                ForEach(0..<transition.durationDays, id: \.self) { day in
                    let ratio = DietTransitionPlan.newFoodRatio(dayIndex: day, durationDays: transition.durationDays)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.butter.opacity(0.25 + ratio * 0.75))
                            .frame(height: 6 + ratio * 26)
                            .frame(height: 32, alignment: .bottom)
                        Text("\(day + 1)")
                            .font(.system(size: 10, weight: day == today ? .bold : .regular))
                            .foregroundStyle(day == today ? Theme.ink : Theme.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Recent logs

struct RecentLogsSection: View {
    let pet: Pet
    @Environment(\.modelContext) private var context

    private var logs: [FeedingLog] {
        Array((pet.feedingLogs ?? []).sorted { $0.date > $1.date }.prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent activity")
            if logs.isEmpty {
                Text("Logged meals, water and treats will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(logs) { log in
                        HStack(spacing: 12) {
                            Image(systemName: log.kind.symbol)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.color(for: log.kind))
                                .frame(width: 28)
                            Text(log.kind.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                            if !log.fedBy.isEmpty {
                                Text(log.fedBy)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                            if log.source == .device {
                                Text(log.deviceName.isEmpty ? String(localized: "Device") : log.deviceName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.sky)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.sky.opacity(0.12), in: Capsule())
                            } else if log.source == .shortcut {
                                Image(systemName: "waveform")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.plum)
                            }
                            Spacer()
                            Text(log.date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .padding(.vertical, 10)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                context.delete(log)
                                try? context.save()
                            }
                        }
                    }
                }
                .card(padding: 14)
            }
        }
    }
}

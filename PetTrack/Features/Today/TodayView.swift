import Charts
import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""
    @State private var showSettings = false

    private var pet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    PetSwitcher(pets: pets, selectedID: $selectedPetID)
                    if let pet {
                        PetHeroCard(pet: pet)
                        TodayFeedingCard(pet: pet)
                        if !pet.openSymptomCases.isEmpty {
                            SymptomWatchCard(pet: pet)
                        }
                        UpcomingCard(pet: pet)
                        if let transition = pet.activeTransition {
                            TransitionProgressCard(transition: transition)
                        }
                        WeightSnapshotCard(pet: pet)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .tabBarSafeArea()
            .background(Theme.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: SymptomCase.self) { symptomCase in
                SymptomCaseDetailView(symptomCase: symptomCase)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkTertiary)
                Text(greeting)
                    .font(.display(34))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 0.5))
            }
            .accessibilityLabel(Text("Settings"))
        }
        .padding(.top, 8)
    }

    private var greeting: LocalizedStringKey {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Hero

struct PetHeroCard: View {
    let pet: Pet

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                PetAvatar(pet: pet, size: 64)
                    .overlay(Circle().strokeBorder(Theme.cream.opacity(0.25), lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name)
                        .font(.display(28))
                        .foregroundStyle(Theme.cream)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.cream.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                stat(title: "Weight", value: pet.latestWeight.map { Formatting.weight($0.kilograms) } ?? "—", symbol: "scalemass.fill")
                stat(title: "Vaccines", value: vaccineSummary, symbol: "syringe.fill")
                stat(title: "Next meal", value: nextMeal ?? "—", symbol: "fork.knife")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(colors: [Theme.forest, Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Theme.petColor(pet.colorIndex).opacity(0.45))
                    .frame(width: 220)
                    .blur(radius: 60)
                    .offset(x: 140, y: -70)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card + 4, style: .continuous))
        }
        .shadow(color: Theme.forestDeep.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    private var subtitle: String {
        [pet.breed.isEmpty ? String(localized: pet.species.title) : pet.breed, pet.ageDescription]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var vaccineSummary: String {
        let attention = pet.vaccinesNeedingAttention.count
        if (pet.vaccinations ?? []).isEmpty { return "—" }
        return attention == 0 ? String(localized: "All set") : String(localized: "\(attention) due")
    }

    private var nextMeal: String? {
        let now = Calendar.current.component(.hour, from: .now) * 60 + Calendar.current.component(.minute, from: .now)
        let meals = pet.sortedSchedules.filter { $0.isEnabled && $0.kind == .meal }
        let next = meals.first { $0.minutesFromMidnight > now } ?? meals.first
        return next.map { Formatting.time(hour: $0.hour, minute: $0.minute) }
    }

    private func stat(title: LocalizedStringKey, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.cream.opacity(0.6))
            Text(value)
                .font(.numeric(16))
                .foregroundStyle(Theme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.cream.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cream.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

// MARK: - Feeding

struct TodayFeedingCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @State private var pendingFeeding: FeedingRequest?

    private var slots: [FeedingSchedule] { pet.sortedSchedules.filter(\.isEnabled) }
    private var todayLogs: [FeedingLog] { pet.logs(on: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Meals & water")
                    .font(.display(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(completedCount)/\(slots.count)")
                    .font(.numeric(15))
                    .foregroundStyle(Theme.inkSecondary)
            }

            if slots.isEmpty {
                Text("No feeding times yet. Add them in Nutrition.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                        row(slot, isLast: index == slots.count - 1)
                    }
                }
                .guideTip(GuideTips.feedingCheck)
            }
        }
        .card()
        .doubleFeedAlert($pendingFeeding, petName: pet.name) { request in
            withAnimation(.snappy) {
                _ = FeedingLogger.log(request.kind, for: pet, amount: request.amount, scheduleID: request.scheduleID, context: context)
            }
        }
    }

    private var completedCount: Int {
        slots.filter { log(for: $0) != nil }.count
    }

    private func log(for slot: FeedingSchedule) -> FeedingLog? {
        todayLogs.first { $0.scheduleID == slot.id }
            ?? todayLogs.first { log in
                // Device-imported events count for the closest slot of the same kind within 90 minutes.
                log.scheduleID == nil && log.kind == slot.kind && abs(log.date.timeIntervalSince(slot.time(on: .now))) < 90 * 60
            }
    }

    private func row(_ slot: FeedingSchedule, isLast: Bool) -> some View {
        let done = log(for: slot)
        let tint = Theme.color(for: slot.kind)
        return HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(done != nil ? tint : Theme.surfaceMuted)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(tint.opacity(0.6), lineWidth: done == nil ? 1.5 : 0))
                if !isLast {
                    Rectangle().fill(Theme.hairline).frame(width: 1.5).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .strikethrough(done != nil, color: Theme.inkTertiary)
                HStack(spacing: 6) {
                    Text(Formatting.time(hour: slot.hour, minute: slot.minute))
                    if !slot.foodName.isEmpty { Text("· \(slot.foodName)") }
                    if let done, !done.fedBy.isEmpty {
                        Text("· \(done.fedBy)")
                    }
                    if let done, done.source == .device {
                        Label("Device", systemImage: "antenna.radiowaves.left.and.right")
                            .labelStyle(.iconOnly)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
            .padding(.vertical, 10)

            Spacer()

            Button { toggle(slot, existing: done) } label: {
                Image(systemName: done != nil ? "checkmark.circle.fill" : slot.kind.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(done != nil ? tint : Theme.inkTertiary)
                    .frame(width: 40, height: 40)
                    .background(done != nil ? tint.opacity(0.14) : Theme.surfaceMuted, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: done != nil)
        }
        .frame(minHeight: 54)
    }

    private func toggle(_ slot: FeedingSchedule, existing: FeedingLog?) {
        if let existing {
            withAnimation(.snappy) {
                context.delete(existing)
                try? context.save()
            }
            return
        }
        if let conflict = FeedingLogger.conflict(for: pet, kind: slot.kind, excludingSchedule: slot.id) {
            pendingFeeding = FeedingRequest(kind: slot.kind, amount: slot.portion, scheduleID: slot.id, existing: conflict)
            return
        }
        withAnimation(.snappy) {
            _ = FeedingLogger.log(slot.kind, for: pet, amount: slot.portion, scheduleID: slot.id, context: context)
        }
    }
}

// MARK: - Upcoming

struct UpcomingCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @State private var showReminderEditor = false
    @State private var editingReminder: Reminder?

    private enum Item: Identifiable {
        case vaccine(Vaccination)
        case reminder(Reminder)
        case followUp(VetVisit)

        var id: String {
            switch self {
            case .vaccine(let v): "v-\(v.id)"
            case .reminder(let r): "r-\(r.id)"
            case .followUp(let visit): "f-\(visit.id)"
            }
        }

        var date: Date {
            switch self {
            case .vaccine(let v): v.nextDueDate ?? .distantFuture
            case .reminder(let r): r.dueDate
            case .followUp(let visit): visit.followUpDate ?? .distantFuture
            }
        }
    }

    private var items: [Item] {
        let horizon = Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now
        let vaccines = (pet.vaccinations ?? [])
            .filter { ($0.nextDueDate ?? .distantFuture) <= horizon }
            .map(Item.vaccine)
        let reminders = pet.openReminders.map(Item.reminder)
        let followUps = (pet.visits ?? [])
            .filter { visit in
                guard let date = visit.followUpDate else { return false }
                return date >= Calendar.current.startOfDay(for: .now) && date <= horizon
            }
            .map(Item.followUp)
        return (vaccines + reminders + followUps).sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Coming up")
                    .font(.display(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    if pet.openReminders.count >= FreeTier.maxOpenReminders && !store.isPremium {
                        store.presentPaywall(.unlimitedReminders)
                    } else {
                        showReminderEditor = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                        .background(Theme.accent.opacity(0.13), in: Circle())
                }
                .accessibilityLabel(Text("Add reminder"))
            }

            if items.isEmpty {
                Text("Nothing due in the next 60 days.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(items.prefix(5)) { item in
                        row(item)
                    }
                }
            }
        }
        .card()
        .sheet(isPresented: $showReminderEditor) {
            NavigationStack { ReminderEditorView(pet: pet) }
        }
        .sheet(item: $editingReminder) { reminder in
            NavigationStack { ReminderEditorView(pet: pet, reminder: reminder) }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        switch item {
        case .vaccine(let vaccine):
            UpcomingRow(symbol: "syringe.fill", tint: Theme.color(for: vaccine.status), title: vaccine.name,
                        date: item.date, isOverdue: vaccine.status == .overdue)
        case .followUp(let visit):
            UpcomingRow(symbol: "stethoscope", tint: Theme.accent, title: String(localized: "Follow-up: \(visit.displayTitle)"),
                        date: item.date, isOverdue: false)
        case .reminder(let reminder):
            HStack {
                Button { editingReminder = reminder } label: {
                    UpcomingRow(symbol: reminder.category.symbol, tint: Theme.plum, title: reminder.title,
                                date: reminder.dueDate, isOverdue: reminder.dueDate < .now)
                }
                .buttonStyle(.plain)
                Button { complete(reminder) } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.sage)
                        .frame(width: 30, height: 30)
                        .background(Theme.sage.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Mark as done"))
            }
        }
    }

    private func complete(_ reminder: Reminder) {
        withAnimation(.snappy) {
            reminder.complete()
            try? context.save()
        }
        NotificationManager.shared.schedule(reminder, petName: pet.name)
    }
}

struct UpcomingRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let date: Date
    let isOverdue: Bool

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(isOverdue ? Theme.danger : Theme.inkSecondary)
            }
            Spacer()
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.numeric(13, weight: .medium))
                .foregroundStyle(Theme.inkTertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Transition

struct TransitionProgressCard: View {
    let transition: DietTransition

    var body: some View {
        let ratio = transition.newFoodRatio()
        let day = min(transition.dayIndex() + 1, transition.durationDays)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconBadge(symbol: "arrow.triangle.swap", tint: Theme.butter, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Food transition")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Day \(day) of \(transition.durationDays)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
            }
            MixBar(newRatio: ratio, newFood: transition.toFood, oldFood: transition.fromFood)
        }
        .card()
    }
}

struct MixBar: View {
    let newRatio: Double
    let newFood: String
    let oldFood: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.butter)
                        .frame(width: max(0, proxy.size.width * newRatio - 1.5))
                    if newRatio < 1 {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.surfaceMuted)
                    }
                }
            }
            .frame(height: 14)
            HStack {
                Label {
                    Text("\(newRatio.formatted(.percent.precision(.fractionLength(0)))) \(newFood)")
                } icon: {
                    Circle().fill(Theme.butter).frame(width: 8, height: 8)
                }
                Spacer()
                if newRatio < 1 {
                    Label {
                        Text("\((1 - newRatio).formatted(.percent.precision(.fractionLength(0)))) \(oldFood)")
                    } icon: {
                        Circle().fill(Theme.inkTertiary).frame(width: 8, height: 8)
                    }
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.inkSecondary)
        }
    }
}

// MARK: - Weight snapshot

struct WeightSnapshotCard: View {
    let pet: Pet

    var body: some View {
        let entries = Array(pet.sortedWeights.suffix(8))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Weight trend")
                    Text(entries.last.map { Formatting.weight($0.kilograms) } ?? "—")
                        .font(.display(28))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                if entries.count >= 2, let last = entries.last, let previous = entries.dropLast().last {
                    let delta = last.kilograms - previous.kilograms
                    Label(Formatting.weight(abs(delta)), systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surfaceMuted, in: Capsule())
                }
            }
            if entries.count >= 2 {
                Chart(entries) { entry in
                    AreaMark(x: .value("Date", entry.date), y: .value("Weight", entry.kilograms))
                        .foregroundStyle(LinearGradient(colors: [Theme.sage.opacity(0.3), Theme.sage.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", entry.date), y: .value("Weight", entry.kilograms))
                        .foregroundStyle(Theme.sage)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 70)
            } else {
                Text("Log weight regularly to see the trend.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .card()
    }
}

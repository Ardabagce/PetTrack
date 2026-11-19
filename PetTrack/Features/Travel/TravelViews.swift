import SwiftData
import SwiftUI

/// Passport tab card that opens the travel planner.
struct TravelCard: View {
    let pet: Pet
    @Environment(StoreManager.self) private var store
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Travel")
                    .font(.display(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if !store.isPremium { PremiumBadge() }
            }
            if pet.upcomingTravelPlans.isEmpty {
                Text("Flying between the US and Europe? Get every vaccine, certificate and deadline for your destination, with countdown reminders.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                ForEach(pet.upcomingTravelPlans) { plan in
                    NavigationLink(value: plan) { TravelPlanRow(plan: plan, pet: pet) }
                        .buttonStyle(.plain)
                }
            }
            Button {
                store.requirePremium(.travelPlanner) { showEditor = true }
            } label: {
                Label("Plan a trip", systemImage: "airplane.departure")
            }
            .buttonStyle(SoftButtonStyle(tint: Theme.sky))
        }
        .card()
        .sheet(isPresented: $showEditor) {
            NavigationStack { TravelPlanEditorView(pet: pet) }
        }
    }
}

struct TravelPlanRow: View {
    let plan: TravelPlan
    let pet: Pet

    var body: some View {
        let destination = TravelRequirements.destination(plan.destinationCode)
        let steps = TravelRequirements.steps(to: destination, arrival: plan.arrivalDate, facts: TravelRequirements.facts(for: pet))
        let done = steps.filter { $0.state(completed: plan.isCompleted($0.id)) == .done }.count
        let overdue = steps.contains { $0.state(completed: plan.isCompleted($0.id)) == .overdue }
        HStack(spacing: 12) {
            Text(destination.flag).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(plan.arrivalDate.formatted(date: .abbreviated, time: .omitted) + " · " + plan.arrivalDate.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(done)/\(steps.count)")
                    .font(.numeric(15))
                    .foregroundStyle(overdue ? Theme.danger : Theme.ink)
                ProgressView(value: Double(done), total: Double(max(steps.count, 1)))
                    .tint(overdue ? Theme.danger : Theme.sage)
                    .frame(width: 54)
            }
        }
        .padding(12)
        .background(Theme.surfaceMuted.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

struct TravelPlanEditorView: View {
    let pet: Pet
    var plan: TravelPlan?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var destinationCode = "DE"
    @State private var departure = Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now
    @State private var arrival = Calendar.current.date(byAdding: .day, value: 46, to: .now) ?? .now
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Destination") {
                Picker("Country", selection: $destinationCode) {
                    ForEach(TravelRequirements.destinations) { destination in
                        Text("\(destination.flag) \(destination.name)").tag(destination.code)
                    }
                }
            }
            Section {
                DatePicker("Departure", selection: $departure, in: Date.now..., displayedComponents: .date)
                DatePicker("Arrival", selection: $arrival, in: departure..., displayedComponents: .date)
            } footer: {
                Text("Deadlines are counted back from the arrival date.")
            }
            Section {
                TextField("Notes (flight, airline, address)", text: $notes, axis: .vertical)
            }
            if let plan {
                Section {
                    Button("Delete trip", role: .destructive) {
                        NotificationManager.shared.cancel(plan)
                        context.delete(plan)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .formCanvas()
        .navigationTitle(plan == nil ? Text("Plan a trip") : Text("Edit trip"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
        }
        .onChange(of: departure) { _, value in if arrival < value { arrival = value } }
        .onAppear {
            if let plan {
                destinationCode = plan.destinationCode
                departure = plan.departureDate
                arrival = plan.arrivalDate
                notes = plan.notes
            } else if Locale.current.region?.identifier != "US" {
                destinationCode = "US"
            }
        }
    }

    private func save() {
        let target = plan ?? TravelPlan(destinationCode: destinationCode, departureDate: departure, arrivalDate: arrival)
        target.destinationCode = destinationCode
        target.departureDate = departure
        target.arrivalDate = arrival
        target.notes = notes
        if plan == nil {
            target.pet = pet
            context.insert(target)
        }
        try? context.save()
        Task {
            await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.schedule(target, pet: pet)
        }
        dismiss()
    }
}

struct TravelPlanDetailView: View {
    @Bindable var plan: TravelPlan
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var showEditor = false

    private var pet: Pet? { plan.pet }
    private var destination: TravelRequirements.Destination { TravelRequirements.destination(plan.destinationCode) }

    private var steps: [TravelRequirements.Step] {
        guard let pet else { return [] }
        return TravelRequirements.steps(to: destination, arrival: plan.arrivalDate, facts: TravelRequirements.facts(for: pet))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 10) {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Rules change. Always confirm with the official source and your airline before you travel.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                    Button("Open official rules") { openURL(TravelRequirements.officialSource(for: destination)) }
                        .font(.footnote.weight(.semibold))
                }
                .card()
            }
            .padding(20)
        }
        .tabBarSafeArea()
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { showEditor = true } }
        .sheet(isPresented: $showEditor) {
            if let pet { NavigationStack { TravelPlanEditorView(pet: pet, plan: plan) } }
        }
    }

    private var header: some View {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                   to: Calendar.current.startOfDay(for: plan.arrivalDate)).day ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRIP")
                        .font(.system(size: 10, weight: .bold)).tracking(2)
                        .foregroundStyle(Theme.cream.opacity(0.6))
                    Text("\(destination.flag) \(destination.name)")
                        .font(.display(28))
                        .foregroundStyle(Theme.cream)
                    Text(plan.arrivalDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Theme.cream.opacity(0.7))
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(max(days, 0))")
                        .font(.display(40))
                        .foregroundStyle(Theme.cream)
                    Text("days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.cream.opacity(0.6))
                }
            }
            if let pet {
                Text("\(pet.name) · \(String(localized: pet.species.title))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.cream.opacity(0.8))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.sky.opacity(0.9), Theme.forestDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private func stepRow(_ step: TravelRequirements.Step) -> some View {
        let state = step.state(completed: plan.isCompleted(step.id))
        let tint: Color = switch state {
        case .done: Theme.sage
        case .ready: Theme.accent
        case .upcoming: Theme.inkTertiary
        case .overdue: Theme.danger
        }
        return HStack(alignment: .top, spacing: 12) {
            Button {
                guard !step.autoSatisfied else { return }
                withAnimation(.snappy) { plan.toggle(step.id) }
                try? context.save()
            } label: {
                Image(systemName: state == .done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: step.symbol).font(.caption).foregroundStyle(tint)
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if step.isRecommendation {
                        StatusPill(text: "Recommended", tint: Theme.inkTertiary)
                    }
                }
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if state != .done {
                    Text(timing(step))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                } else if step.autoSatisfied {
                    Text("Found in \(pet?.name ?? "")'s records")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.sage)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    private func timing(_ step: TravelRequirements.Step) -> String {
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted)
        switch (step.windowStart, step.deadline) {
        case let (start?, end?):
            return String(localized: "Between \(start.formatted(format)) and \(end.formatted(format))")
        case let (nil, end?):
            return String(localized: "By \(end.formatted(format))")
        case let (start?, nil):
            return String(localized: "From \(start.formatted(format))")
        case (nil, nil):
            return ""
        }
    }
}

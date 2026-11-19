import SwiftData
import SwiftUI

enum QuickAction: String, Identifiable, CaseIterable {
    case weight, visit, scan, vaccine, expense, reminder

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .weight: "Weight"
        case .visit: "Vet visit"
        case .scan: "Scan report"
        case .vaccine: "Vaccine"
        case .expense: "Expense"
        case .reminder: "Reminder"
        }
    }

    var symbol: String {
        switch self {
        case .weight: "scalemass.fill"
        case .visit: "stethoscope"
        case .scan: "doc.text.viewfinder"
        case .vaccine: "syringe.fill"
        case .expense: "creditcard.fill"
        case .reminder: "bell.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight: Theme.sage
        case .visit: Theme.accent
        case .scan: Theme.plum
        case .vaccine: Theme.sky
        case .expense: Theme.butter
        case .reminder: Theme.accent
        }
    }
}

struct QuickAddSheet: View {
    var onSelect: (QuickAction) -> Void

    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""
    @State private var loggedKind: FeedingKind?
    @State private var pendingFeeding: FeedingRequest?

    private var pet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Quick add")
                    Text(pet?.name ?? "")
                        .font(.display(26))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                if let pet { PetAvatar(pet: pet, size: 40) }
            }

            HStack(spacing: 10) {
                ForEach(FeedingKind.allCases) { kind in
                    Button { log(kind) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: loggedKind == kind ? "checkmark" : kind.symbol)
                                .contentTransition(.symbolEffect(.replace))
                            Text(kind.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.color(for: kind))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.color(for: kind).opacity(0.13), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .sensoryFeedback(.success, trigger: loggedKind)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(QuickAction.allCases) { action in
                    Button { onSelect(action) } label: {
                        VStack(spacing: 10) {
                            IconBadge(symbol: action.symbol, tint: action.tint, size: 42)
                            HStack(spacing: 4) {
                                Text(action.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if action == .scan && !store.isPremium { PremiumBadge() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(22)
        .doubleFeedAlert($pendingFeeding, petName: pet?.name ?? "") { request in
            commit(request.kind)
        }
    }

    private func log(_ kind: FeedingKind) {
        guard let pet else { return }
        if let existing = FeedingLogger.conflict(for: pet, kind: kind) {
            pendingFeeding = FeedingRequest(kind: kind, amount: 0, scheduleID: nil, existing: existing)
            return
        }
        commit(kind)
    }

    private func commit(_ kind: FeedingKind) {
        guard let pet else { return }
        FeedingLogger.log(kind, for: pet, context: context)
        withAnimation { loggedKind = kind }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if loggedKind == kind { loggedKind = nil } }
        }
    }

}

/// The editor presented for a quick action.
struct QuickActionDestination: View {
    let action: QuickAction
    let pet: Pet

    var body: some View {
        NavigationStack {
            switch action {
            case .weight: WeightEditorView(pet: pet)
            case .visit: VetVisitEditorView(pet: pet)
            case .scan: ScanReportView(pet: pet)
            case .vaccine: VaccinationEditorView(pet: pet)
            case .expense: ExpenseEditorView(pet: pet)
            case .reminder: ReminderEditorView(pet: pet)
            }
        }
    }
}

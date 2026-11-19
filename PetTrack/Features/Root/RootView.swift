import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @AppStorage("selectedPetID") private var selectedPetID = ""

    @State private var tab: AppTab = .today
    @State private var showQuickAdd = false
    @State private var pendingAction: QuickAction?
    @State private var activeAction: QuickAction?
    @AppStorage(GuideState.tourCompletedKey) private var tourCompleted = false
    @AppStorage(GuideState.lastSeenWhatsNewKey) private var lastSeenWhatsNew = ""
    @State private var showTour = false
    @State private var whatsNew: WhatsNewCatalog.Release?

    private var selectedPet: Pet? { pets.selected(id: selectedPetID) }

    var body: some View {
        @Bindable var store = store
        Group {
            if pets.isEmpty {
                OnboardingView()
            } else {
                ZStack(alignment: .bottom) {
                    ZStack {
                        TodayView().tabVisible(tab == .today)
                        HealthView().tabVisible(tab == .health)
                        NutritionView().tabVisible(tab == .nutrition)
                        PassportView().tabVisible(tab == .passport)
                    }
                    FloatingTabBar(selection: $tab) { showQuickAdd = true }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
        .sheet(isPresented: $showQuickAdd, onDismiss: handleQuickAddDismiss) {
            QuickAddSheet { action in
                pendingAction = action
                showQuickAdd = false
            }
            .presentationDetents([.height(430)])
            .presentationCornerRadius(32)
            .presentationBackground(Theme.canvas)
        }
        .sheet(item: $activeAction) { action in
            if let pet = selectedPet {
                QuickActionDestination(action: action, pet: pet)
            }
        }
        .sheet(item: $store.paywallContext) { context in
            PaywallView(context: context)
        }
        .fullScreenCover(isPresented: $showTour) { FeatureTourView() }
        .sheet(isPresented: Binding(get: { whatsNew != nil }, set: { if !$0 { whatsNew = nil } })) {
            if let whatsNew { WhatsNewView(release: whatsNew).presentationDetents([.large]) }
        }
        .onChange(of: pets.isEmpty) { _, isEmpty in
            if !isEmpty && !tourCompleted { showTour = true }
        }
        .onAppear(perform: presentGuideIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await syncHousehold() }
        }
    }

    /// First launch with a pet → tour. After an update → "What's new" once.
    private func presentGuideIfNeeded() {
        guard !pets.isEmpty else { return }
        if !tourCompleted {
            showTour = true
        } else if let release = WhatsNewCatalog.pendingRelease(lastSeen: lastSeenWhatsNew) {
            whatsNew = release
        }
        lastSeenWhatsNew = WhatsNewCatalog.latest?.version ?? WhatsNewCatalog.currentVersion
    }

    /// Opens the chosen editor once the quick-add sheet has closed, or the paywall when the action needs Premium.
    private func handleQuickAddDismiss() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        if action == .scan && !store.isPremium {
            store.presentPaywall(.reportScanning)
        } else if action == .reminder, let pet = selectedPet,
                  pet.openReminders.count >= FreeTier.maxOpenReminders, !store.isPremium {
            store.presentPaywall(.unlimitedReminders)
        } else {
            activeAction = action
        }
    }

    private func syncHousehold() async {
        await HouseholdService.shared.sync(context: context)
    }
}

private extension View {
    func tabVisible(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .environment(\.isActiveTab, visible)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

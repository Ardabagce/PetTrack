import SwiftData
import SwiftUI

@main
struct PetTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = StoreManager()
    @State private var household = HouseholdService.shared

    init() {
        GuideTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(household)
                .tint(Theme.accent)
                .task { await store.start() }
        }
        .modelContainer(Persistence.container)
    }
}

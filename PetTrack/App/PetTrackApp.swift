import SwiftData
import SwiftUI

@main
struct PetTrackApp: App {
    @State private var store = StoreManager()

    init() {
        GuideTips.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                .task { await store.start() }
        }
        .modelContainer(Persistence.container)
    }
}

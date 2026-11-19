import SwiftData
import SwiftUI

struct FeedersView: View {
    @Bindable var pet: Pet
    @Environment(\.modelContext) private var context
    @State private var isSyncing = false
    @State private var lastResult: Int?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart feeders")
                        .font(.display(30))
                        .foregroundStyle(Theme.ink)
                    Text("Connect a device and every dispensed meal or water refill is added to \(pet.name)'s log automatically.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }

                if let provider = FeederRegistry.provider(id: pet.feederProviderID) {
                    connectedCard(provider)
                }

                VStack(spacing: 10) {
                    ForEach(FeederRegistry.providers, id: \.id) { provider in
                        providerRow(provider)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Using Shortcuts", systemImage: "square.2.layers.3d")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Any device that works with Apple Shortcuts or Home automations can log a feeding with the “Log a feeding” action – no vendor integration needed.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .card()
            }
            .padding(20)
        }
        .tabBarSafeArea()
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func connectedCard(_ provider: any SmartFeederProvider) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IconBadge(symbol: provider.symbol, tint: Theme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    if let last = pet.feederLastSync {
                        Text("Last sync \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                Spacer()
                StatusPill(text: "Connected", tint: Theme.sage)
            }
            if let lastResult {
                Text("\(lastResult) new events imported")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await sync() }
                } label: {
                    if isSyncing { ProgressView() } else { Label("Sync now", systemImage: "arrow.triangle.2.circlepath") }
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.sage))
                .disabled(isSyncing)

                Button("Disconnect") {
                    pet.feederProviderID = ""
                    pet.feederLastSync = nil
                    try? context.save()
                }
                .buttonStyle(SoftButtonStyle(tint: Theme.danger))
            }
        }
        .card()
    }

    private func providerRow(_ provider: any SmartFeederProvider) -> some View {
        let isConnected = pet.feederProviderID == provider.id
        return Button {
            guard provider.status == .available, !isConnected else { return }
            pet.feederProviderID = provider.id
            pet.feederLastSync = Calendar.current.startOfDay(for: .now)
            try? context.save()
            Task { await sync() }
        } label: {
            HStack(spacing: 14) {
                IconBadge(symbol: provider.symbol, tint: provider.status == .available ? Theme.sky : Theme.inkTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(provider.deviceTypes)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                switch provider.status {
                case .available:
                    if isConnected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sage)
                    } else {
                        Text("Connect")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                case .comingSoon:
                    StatusPill(text: "Coming soon", tint: Theme.inkTertiary)
                }
            }
            .card(padding: 14)
        }
        .buttonStyle(PressableStyle())
        .disabled(provider.status == .comingSoon)
    }

    private func sync() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            lastResult = try await FeederSyncService.sync(pet: pet, context: context)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

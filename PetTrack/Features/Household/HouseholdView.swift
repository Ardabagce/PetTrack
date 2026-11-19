import CloudKit
import SwiftData
import SwiftUI
import UIKit

/// Settings → Family: invite family members so everyone sees who fed the pet.
struct HouseholdView: View {
    @Environment(HouseholdService.self) private var household
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @State private var name = ""
    @State private var sharing: SharingItem?
    @State private var isPreparing = false
    @State private var errorMessage: String?
    @State private var paywall: PaywallContext?

    struct SharingItem: Identifiable {
        let id = UUID()
        let share: CKShare
        let container: CKContainer
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: -10) {
                        ForEach(Array(["person.fill", "person.fill", "pawprint.fill"].enumerated()), id: \.offset) { index, symbol in
                            Image(systemName: symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.cream)
                                .frame(width: 42, height: 42)
                                .background(Theme.petPalette[index], in: Circle())
                                .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 3))
                        }
                    }
                    Text("Who fed the dog?")
                        .font(.display(24))
                    Text("Invite your family. When anyone ticks off a meal, everyone sees it right away – with their name and the time. If someone tries to feed again, PetTrack asks first.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .onSubmit { household.memberName = name }
                    .onChange(of: name) { _, value in household.memberName = value.trimmingCharacters(in: .whitespaces) }
            } header: {
                Text("You")
            } footer: {
                Text("Shown next to everything you log, e.g. “Dinner · Alex”.")
            }

            Section("Household") {
                switch household.role {
                case .none:
                    Button {
                        if store.isPremium {
                            Task { await invite() }
                        } else {
                            paywall = PaywallContext(feature: .familySharing)
                        }
                    } label: {
                        HStack {
                            Label("Invite family members", systemImage: "person.badge.plus")
                            Spacer()
                            if isPreparing { ProgressView() } else if !store.isPremium { PremiumBadge() }
                        }
                    }
                    .disabled(isPreparing || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Enter your name first.")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                case .owner:
                    Label("You manage this household", systemImage: "house.fill")
                    Button("Manage people") { Task { await invite() } }
                    syncRow
                case .member:
                    Label("You joined a household", systemImage: "person.2.fill")
                    syncRow
                    Button("Leave household", role: .destructive) { household.leave() }
                }
            }

            if !household.accountAvailable {
                Section {
                    Label("Sign in to iCloud in Settings to share with your family.", systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                }
            }

            Section {
                Label("Shared: pets, feeding times and every meal, water refill and treat.", systemImage: "checkmark.circle")
                Label("Private: health records, documents and costs stay on your devices.", systemImage: "lock.fill")
            } header: {
                Text("What is shared")
            }
            .font(.footnote)
        }
        .formCanvas()
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = household.memberName }
        .task { await household.refreshAccountStatus() }
        .sheet(item: $sharing) { item in
            CloudSharingView(share: item.share, container: item.container)
                .ignoresSafeArea()
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    @ViewBuilder
    private var syncRow: some View {
        Button {
            Task { await household.sync(context: context) }
        } label: {
            HStack {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                switch household.status {
                case .syncing: ProgressView()
                case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger)
                case .idle: EmptyView()
                }
            }
        }
        if case .failed(let message) = household.status {
            Text(message).font(.footnote).foregroundStyle(Theme.danger)
        }
    }

    private func invite() async {
        household.memberName = name.trimmingCharacters(in: .whitespaces)
        isPreparing = true
        defer { isPreparing = false }
        do {
            let (share, container) = try await household.prepareShare(pets: pets, context: context)
            sharing = SharingItem(share: share, container: container)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// System sheet for inviting people (Messages, Mail, link) and managing participants.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

        func itemTitle(for csc: UICloudSharingController) -> String? {
            String(localized: "PetTrack household")
        }
    }
}

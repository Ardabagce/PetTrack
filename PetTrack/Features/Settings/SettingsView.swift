import StoreKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(WeightUnitPreference.storageKey) private var weightUnitRaw = WeightUnitPreference.automatic.rawValue
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showManageSubscriptions = false
    // Presented locally: the root paywall can't present on top of this sheet.
    @State private var paywall: PaywallContext?
    @State private var showTour = false
    @State private var showWhatsNew = false
    @State private var tipsReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.isPremium {
                        HStack(spacing: 14) {
                            IconBadge(symbol: "checkmark.seal.fill", tint: Theme.sage)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PetTrack Premium").font(.headline)
                                Text("All features unlocked").font(.caption).foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        Button("Manage subscription") { showManageSubscriptions = true }
                    } else {
                        Button { paywall = PaywallContext(feature: nil) } label: {
                            HStack(spacing: 14) {
                                IconBadge(symbol: "sparkles", tint: Theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("Upgrade to Premium").font(.headline).foregroundStyle(Theme.ink)
                                        PremiumBadge()
                                    }
                                    Text("3 days free, then monthly or yearly").font(.caption).foregroundStyle(Theme.inkSecondary)
                                }
                            }
                        }
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                }

                Section("Preferences") {
                    Picker("Weight unit", selection: $weightUnitRaw) {
                        ForEach(WeightUnitPreference.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        HStack {
                            Text("Language").foregroundStyle(Theme.ink)
                            Spacer()
                            Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "")
                                .foregroundStyle(Theme.inkSecondary)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Notifications")
                        Spacer()
                        Text(statusText).foregroundStyle(Theme.inkSecondary)
                    }
                    if notificationStatus == .notDetermined {
                        Button("Enable notifications") {
                            Task {
                                await NotificationManager.shared.requestAuthorization()
                                notificationStatus = await NotificationManager.shared.authorizationStatus()
                            }
                        }
                    } else if notificationStatus == .denied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Feeding times, vaccine boosters, food transitions and your own reminders.")
                }

                Section {
                    Button("Show the tour") { showTour = true }
                    Button("What's new") { showWhatsNew = true }
                    Button(tipsReset ? LocalizedStringKey("Hints will reappear next launch") : LocalizedStringKey("Show hints again")) {
                        UserDefaults.standard.set(true, forKey: GuideState.resetTipsKey)
                        tipsReset = true
                    }
                    .disabled(tipsReset)
                } header: {
                    Text("Guide")
                }

                Section("About") {
                    Button("Contact support") { openURL(AppLinks.support) }
                    Button("Privacy policy") { openURL(AppLinks.privacy) }
                    Button("Terms of use") { openURL(AppLinks.terms) }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }

                #if DEBUG
                Section("Developer") {
                    Toggle("Simulate Premium", isOn: Binding(
                        get: { store.debugPremiumOverride },
                        set: { store.setDebugPremiumOverride($0) }
                    ))
                }
                #endif
            }
            .formCanvas()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .sheet(item: $paywall) { PaywallView(context: $0) }
            .fullScreenCover(isPresented: $showTour) { FeatureTourView() }
            .sheet(isPresented: $showWhatsNew) {
                if let release = WhatsNewCatalog.latest { WhatsNewView(release: release) }
            }
            .task { notificationStatus = await NotificationManager.shared.authorizationStatus() }
        }
    }

    private var statusText: LocalizedStringKey {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        default: "Not set"
        }
    }
}

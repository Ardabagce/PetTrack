import StoreKit
import SwiftUI

struct PaywallView: View {
    let context: PaywallContext

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = StoreManager.yearlyID

    private var selected: Product? { store.products.first { $0.id == selectedID } }

    /// Highlighted feature first, then the rest.
    private var features: [PremiumFeature] {
        guard let feature = context.feature else { return PremiumFeature.allCases }
        return [feature] + PremiumFeature.allCases.filter { $0 != feature }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.forestDeep.ignoresSafeArea()
            Circle()
                .fill(Theme.accent.opacity(0.4))
                .frame(width: 360)
                .blur(radius: 100)
                .offset(x: 120, y: -220)
            Circle()
                .fill(Theme.sage.opacity(0.3))
                .frame(width: 300)
                .blur(radius: 100)
                .offset(x: -160, y: 260)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(features) { feature in
                            featureRow(feature, highlighted: feature == context.feature)
                        }
                    }
                    plans
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 220)
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                footer
            }

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.cream.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(Theme.cream.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(Text("Close"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .preferredColorScheme(.dark)
        .task { await store.loadProducts() }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            PremiumBadge()
            Text("Everything your pet's health needs, in one place.")
                .font(.display(34))
                .foregroundStyle(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
            Text("Try PetTrack Premium free for 3 days. Cancel anytime.")
                .font(.body)
                .foregroundStyle(Theme.cream.opacity(0.7))
        }
    }

    private func featureRow(_ feature: PremiumFeature, highlighted: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(highlighted ? Theme.forestDeep : Theme.cream)
                .frame(width: 38, height: 38)
                .background(highlighted ? Color(hex: 0xF3D38A) : Theme.cream.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(Theme.cream)
                Text(feature.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.cream.opacity(0.65))
            }
        }
    }

    @ViewBuilder
    private var plans: some View {
        if store.products.isEmpty {
            HStack {
                Spacer()
                if store.isLoadingProducts {
                    ProgressView().tint(Theme.cream)
                } else {
                    Text("Subscriptions are currently unavailable.")
                        .font(.footnote)
                        .foregroundStyle(Theme.cream.opacity(0.6))
                }
                Spacer()
            }
            .padding(.vertical, 20)
        } else {
            VStack(spacing: 12) {
                if let yearly = store.yearly { planCard(yearly, isYearly: true) }
                if let monthly = store.monthly { planCard(monthly, isYearly: false) }
            }
        }
    }

    private func planCard(_ product: Product, isYearly: Bool) -> some View {
        let isSelected = selectedID == product.id
        return Button {
            withAnimation(.snappy) { selectedID = product.id }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color(hex: 0xF3D38A) : Theme.cream.opacity(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? LocalizedStringKey("Yearly") : LocalizedStringKey("Monthly"))
                            .font(.headline)
                            .foregroundStyle(Theme.cream)
                        if isYearly, let savings = store.yearlySavings {
                            Text("Save \(savings.formatted(.percent.precision(.fractionLength(0))))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.forestDeep)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF3D38A), in: Capsule())
                        }
                    }
                    if let trial = store.trialDescription(for: product) {
                        Text("\(trial) free trial")
                            .font(.caption)
                            .foregroundStyle(Theme.cream.opacity(0.65))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.numeric(17))
                        .foregroundStyle(Theme.cream)
                    if isYearly {
                        Text("\((product.price / 12).formatted(product.priceFormatStyle)) / mo")
                            .font(.caption)
                            .foregroundStyle(Theme.cream.opacity(0.55))
                    } else {
                        Text("per month")
                            .font(.caption)
                            .foregroundStyle(Theme.cream.opacity(0.55))
                    }
                }
            }
            .padding(16)
            .background(Theme.cream.opacity(isSelected ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Color(hex: 0xF3D38A) : Theme.cream.opacity(0.12), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let selected else { return }
                Task { await store.purchase(selected) }
            } label: {
                if store.purchaseInProgress {
                    ProgressView().tint(Theme.forestDeep)
                } else if let selected, store.trialDescription(for: selected) != nil {
                    Text("Start free trial")
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: Theme.cream, foreground: Theme.forestDeep))
            .disabled(selected == nil || store.purchaseInProgress)

            Text(legalLine)
                .font(.caption2)
                .foregroundStyle(Theme.cream.opacity(0.55))
                .multilineTextAlignment(.center)

            HStack(spacing: 18) {
                Button("Restore purchases") { Task { await store.restore() } }
                Button("Terms") { openURL(AppLinks.terms) }
                Button("Privacy") { openURL(AppLinks.privacy) }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.cream.opacity(0.75))
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [Theme.forestDeep.opacity(0), Theme.forestDeep, Theme.forestDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    /// Clear pricing text required by App Store guideline 3.1.2.
    private var legalLine: String {
        guard let selected else { return "" }
        let period = selected.id == StoreManager.yearlyID ? String(localized: "year") : String(localized: "month")
        if let trial = store.trialDescription(for: selected) {
            return String(localized: "\(trial) free, then \(selected.displayPrice) per \(period). Renews automatically until cancelled in Settings at least 24 hours before the end of the period.")
        }
        return String(localized: "\(selected.displayPrice) per \(period). Renews automatically until cancelled in Settings at least 24 hours before the end of the period.")
    }
}

enum AppLinks {
    // Replace with your hosted pages before submitting to the App Store.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://pettrack.app/privacy")!
    static let support = URL(string: "mailto:support@pettrack.app")!
}

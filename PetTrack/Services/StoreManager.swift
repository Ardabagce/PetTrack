import Foundation
import Observation
import StoreKit

/// What the free tier includes. Everything beyond these limits requires Premium.
enum FreeTier {
    static let maxPets = 1
    static let maxOpenReminders = 3
    static let maxFeedingSlots = 3
    static let maxSymptomCases = 1
}

enum PremiumFeature: String, CaseIterable, Identifiable {
    case unlimitedPets, familySharing, reportScanning, symptomDiary, travelPlanner, claimPack, passportExport, dietTransition, costInsights, unlimitedReminders

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .unlimitedPets: "Unlimited pets"
        case .familySharing: "Family sharing"
        case .travelPlanner: "US ⇄ Europe travel planner"
        case .claimPack: "Insurance claim pack"
        case .reportScanning: "Scan vet reports"
        case .symptomDiary: "Symptom photo diary"
        case .passportExport: "Shareable health passport"
        case .dietTransition: "Food transition planner"
        case .costInsights: "Cost insights"
        case .unlimitedReminders: "Unlimited reminders & feeding slots"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .unlimitedPets: "Keep every companion's records in one place."
        case .familySharing: "Everyone sees who fed the pet – no more double dinners."
        case .travelPlanner: "Every vaccine, certificate and deadline for your trip, with countdown reminders."
        case .claimPack: "Invoice, report and symptom diary in one PDF, ready for your insurer."
        case .reportScanning: "Turn a photo of any vet report into a visit record."
        case .symptomDiary: "Track a rash, lump or limp day by day and show your vet the whole story."
        case .passportExport: "Send a complete PDF passport to any vet in one tap."
        case .dietTransition: "Day-by-day mixing plan with gentle reminders."
        case .costInsights: "See where your money goes, month by month."
        case .unlimitedReminders: "Medication, grooming, flea & tick – never miss one."
        }
    }

    var symbol: String {
        switch self {
        case .unlimitedPets: "pawprint.fill"
        case .familySharing: "person.2.fill"
        case .travelPlanner: "airplane"
        case .claimPack: "doc.badge.plus"
        case .reportScanning: "doc.text.viewfinder"
        case .symptomDiary: "camera.metering.spot"
        case .passportExport: "person.text.rectangle.fill"
        case .dietTransition: "arrow.triangle.swap"
        case .costInsights: "chart.bar.fill"
        case .unlimitedReminders: "bell.badge.fill"
        }
    }
}

struct PaywallContext: Identifiable {
    let id = UUID()
    var feature: PremiumFeature?
}

@Observable
@MainActor
final class StoreManager {
    static let monthlyID = "com.pettrack.premium.monthly"
    static let yearlyID = "com.pettrack.premium.yearly"
    static let productIDs = [monthlyID, yearlyID]

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var trialEligibility: [String: Bool] = [:]
    var purchaseInProgress = false
    var errorMessage: String?

    /// Set to show the paywall from anywhere in the app.
    var paywallContext: PaywallContext?

    /// Debug-only switch to explore premium features without a sandbox purchase.
    private(set) var debugPremiumOverride: Bool = UserDefaults.standard.bool(forKey: "debugPremiumOverride")

    private var updatesTask: Task<Void, Never>?

    var isPremium: Bool {
        #if DEBUG
        if debugPremiumOverride { return true }
        #endif
        return !purchasedProductIDs.isEmpty
    }

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }

    /// Yearly saving compared with paying monthly for 12 months, e.g. 0.42 for 42%.
    var yearlySavings: Double? {
        guard let monthly, let yearly else { return nil }
        let monthlyYear = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        let yearlyPrice = NSDecimalNumber(decimal: yearly.price).doubleValue
        guard monthlyYear > 0, yearlyPrice < monthlyYear else { return nil }
        return 1 - yearlyPrice / monthlyYear
    }

    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            for product in products {
                if let subscription = product.subscription {
                    trialEligibility[product.id] = await subscription.isEligibleForIntroOffer
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil, Self.productIDs.contains(transaction.productID) {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
    }

    func isEligibleForTrial(_ product: Product) -> Bool {
        trialEligibility[product.id] ?? false
    }

    /// Returns the free-trial length of a product, e.g. "3 days", if the user is eligible.
    func trialDescription(for product: Product) -> String? {
        guard isEligibleForTrial(product),
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return offer.period.localizedDescription
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: Gating

    func presentPaywall(_ feature: PremiumFeature? = nil) {
        paywallContext = PaywallContext(feature: feature)
    }

    /// Runs `action` for premium users, otherwise shows the paywall for `feature`.
    func requirePremium(_ feature: PremiumFeature, _ action: () -> Void) {
        if isPremium {
            action()
        } else {
            presentPaywall(feature)
        }
    }

    func setDebugPremiumOverride(_ value: Bool) {
        debugPremiumOverride = value
        UserDefaults.standard.set(value, forKey: "debugPremiumOverride")
    }
}

extension Product.SubscriptionPeriod {
    var localizedDescription: String {
        let components: DateComponents
        switch unit {
        case .day: components = DateComponents(day: value)
        case .week: components = DateComponents(weekOfMonth: value)
        case .month: components = DateComponents(month: value)
        case .year: components = DateComponents(year: value)
        @unknown default: components = DateComponents(day: value)
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: components) ?? ""
    }
}

import SwiftUI
import TipKit

/// Contextual hints shown once, right where a feature lives (Apple TipKit).
/// Tips appear only after the welcome tour, one at a time.
enum GuideTips {
    static let quickAdd = QuickAddTip()
    static let petSwitcher = PetSwitcherTip()
    static let feedingCheck = FeedingCheckTip()
    static let scanReport = ScanReportTip()
    static let symptomDiary = SymptomDiaryTip()
    static let sharePassport = SharePassportTip()

    static func configure() {
        if UserDefaults.standard.bool(forKey: GuideState.resetTipsKey) {
            try? Tips.resetDatastore()
            UserDefaults.standard.set(false, forKey: GuideState.resetTipsKey)
        }
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}

enum GuideState {
    static let tourCompletedKey = "guide.tourCompleted"
    static let resetTipsKey = "guide.resetTipsOnLaunch"
    static let lastSeenWhatsNewKey = "guide.lastSeenWhatsNew"
}

extension View {
    /// Attaches a tip only once the welcome tour is finished, so first-time users aren't overwhelmed.
    func guideTip(_ tip: some Tip, arrowEdge: Edge = .top) -> some View {
        modifier(GuideTipModifier(tip: tip, arrowEdge: arrowEdge))
    }
}

private struct GuideTipModifier<T: Tip>: ViewModifier {
    let tip: T
    let arrowEdge: Edge
    @AppStorage(GuideState.tourCompletedKey) private var tourCompleted = false
    @Environment(\.isActiveTab) private var isActiveTab

    func body(content: Content) -> some View {
        // Tabs stay mounted while hidden, so only the visible tab may present tips.
        content.popoverTip(tourCompleted && isActiveTab ? tip : nil, arrowEdge: arrowEdge)
    }
}

private struct IsActiveTabKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var isActiveTab: Bool {
        get { self[IsActiveTabKey.self] }
        set { self[IsActiveTabKey.self] = newValue }
    }
}

struct QuickAddTip: Tip {
    var title: Text { Text("Add anything in seconds") }
    var message: Text? { Text("Log a meal, weight, vet visit, expense or reminder from any screen.") }
    var image: Image? { Image(systemName: "plus.circle.fill") }
}

struct PetSwitcherTip: Tip {
    var title: Text { Text("Switch between pets") }
    var message: Text? { Text("Every tab follows the pet you pick here.") }
    var image: Image? { Image(systemName: "pawprint.fill") }
}

struct FeedingCheckTip: Tip {
    var title: Text { Text("Tick off meals") }
    var message: Text? { Text("Tap the circle when a meal or water refill is done.") }
    var image: Image? { Image(systemName: "checkmark.circle") }
}

struct ScanReportTip: Tip {
    var title: Text { Text("Skip the typing") }
    var message: Text? { Text("Photograph a vet report and PetTrack fills in diagnosis, treatment, weight, cost and vaccines.") }
    var image: Image? { Image(systemName: "doc.text.viewfinder") }
}

struct SymptomDiaryTip: Tip {
    var title: Text { Text("Spotted something odd?") }
    var message: Text? { Text("Start a symptom diary and add a photo each day. Your vet sees exactly how it changed.") }
    var image: Image? { Image(systemName: "camera.metering.spot") }
}

struct SharePassportTip: Tip {
    var title: Text { Text("Ready for emergencies") }
    var message: Text? { Text("Share the full health passport with any vet in one tap – even a clinic you've never visited.") }
    var image: Image? { Image(systemName: "staroflife.fill") }
}

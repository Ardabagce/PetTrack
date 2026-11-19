import SwiftUI

/// A short walkthrough of where everything lives. Shown after the first pet is added
/// and available again from Settings → "Show the tour".
struct FeatureTourView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GuideState.tourCompletedKey) private var tourCompleted = false
    @State private var page = 0

    struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let eyebrow: LocalizedStringKey
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    static let pages: [Page] = [
        Page(id: 0, symbol: "sun.max.fill", tint: Theme.butter, eyebrow: "Today",
             title: "Your daily overview",
             message: "Meals and water to tick off, what's coming up and how your pet's weight is trending – all on one screen."),
        Page(id: 1, symbol: "heart.text.square.fill", tint: Theme.accent, eyebrow: "Health",
             title: "The complete medical history",
             message: "Vaccines with booster reminders, a vet journal, a symptom photo diary, weight charts and every bill."),
        Page(id: 2, symbol: "fork.knife", tint: Theme.sage, eyebrow: "Nutrition",
             title: "Feeding, made routine",
             message: "Daily meal and water times, gentle food transitions and sync with smart feeders."),
        Page(id: 3, symbol: "person.text.rectangle.fill", tint: Theme.sky, eyebrow: "Passport",
             title: "Ready when it matters",
             message: "Microchip, allergies, vet contacts and a shareable PDF passport for emergencies or a new vet."),
        Page(id: 4, symbol: "plus", tint: Theme.plum, eyebrow: "Quick add",
             title: "One button for everything",
             message: "The + in the middle of the tab bar logs anything in a couple of taps. Small hints will point out the rest as you go."),
    ]

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Self.pages) { item in
                        pageView(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(Self.pages) { item in
                        Capsule()
                            .fill(item.id == page ? Theme.ink : Theme.hairline)
                            .frame(width: item.id == page ? 22 : 7, height: 7)
                    }
                }
                .animation(.snappy, value: page)
                .padding(.bottom, 22)

                Button {
                    if page < Self.pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < Self.pages.count - 1 ? LocalizedStringKey("Next") : LocalizedStringKey("Get started"))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().fill(item.tint.opacity(0.12)).frame(width: 230)
                Circle().fill(item.tint.opacity(0.18)).frame(width: 160)
                Image(systemName: item.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(item.tint)
            }
            VStack(spacing: 12) {
                Eyebrow(item.eyebrow, color: item.tint)
                Text(item.title)
                    .font(.display(30))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(item.message)
                    .font(.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func finish() {
        tourCompleted = true
        dismiss()
    }
}

// MARK: - What's new

/// Release notes shown once after an update. Add an entry here with every release that ships new features.
enum WhatsNewCatalog {
    struct Item: Identifiable {
        let id = UUID()
        let symbol: String
        let tint: Color
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    struct Release {
        let version: String
        let items: [Item]
    }

    static let releases: [Release] = [
        Release(version: "1.0.0", items: [
            Item(symbol: "camera.metering.spot", tint: Theme.accent, title: "Symptom photo diary",
                 message: "Track a rash, lump or limp day by day and show your vet the whole story."),
            Item(symbol: "doc.text.viewfinder", tint: Theme.plum, title: "Scan vet reports",
                 message: "Turn a photo of any vet report into a visit record."),
            Item(symbol: "person.text.rectangle.fill", tint: Theme.sky, title: "Shareable health passport",
                 message: "Send a complete PDF passport to any vet in one tap."),
        ]),
    ]

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var latest: Release? { releases.last }

    /// The release to announce, if the user hasn't seen it yet. First installs see the tour instead.
    static func pendingRelease(lastSeen: String) -> Release? {
        guard let latest, !lastSeen.isEmpty,
              latest.version.compare(lastSeen, options: .numeric) == .orderedDescending else { return nil }
        return latest
    }
}

struct WhatsNewView: View {
    let release: WhatsNewCatalog.Release
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Version \(release.version)")
                Text("What's new")
                    .font(.display(34))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.top, 30)
            ForEach(release.items) { item in
                HStack(alignment: .top, spacing: 16) {
                    IconBadge(symbol: item.symbol, tint: item.tint, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.headline).foregroundStyle(Theme.ink)
                        Text(item.message).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
            Spacer()
            Button("Continue") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(Theme.canvas.ignoresSafeArea())
    }
}

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, health, nutrition, passport

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .today: "Today"
        case .health: "Health"
        case .nutrition: "Nutrition"
        case .passport: "Passport"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .health: "heart.text.square"
        case .nutrition: "fork.knife"
        case .passport: "person.text.rectangle"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .health: "heart.text.square.fill"
        case .nutrition: "fork.knife"
        case .passport: "person.text.rectangle.fill"
        }
    }
}

/// Floating capsule tab bar with a central quick-add button.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.today)
            tabButton(.health)
            addButton
            tabButton(.nutrition)
            tabButton(.passport)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Theme.surface.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { selection = tab }
        } label: {
            Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.ink : Theme.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Theme.surfaceMuted)
                        .matchedGeometryEffect(id: "selection", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Icons only on screen; VoiceOver and the large-content viewer still get the name.
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Label { Text(tab.title) } icon: { Image(systemName: tab.selectedSymbol) }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.cream)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(colors: [Theme.accent, Color(hex: 0xB4482A)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 4)
        .accessibilityLabel(Text("Add"))
        .guideTip(GuideTips.quickAdd, arrowEdge: .bottom)
    }
}

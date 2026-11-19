import SwiftUI

// MARK: - Card

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var background: Color = Theme.surface

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 14, x: 0, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = 18, background: Color = Theme.surface) -> some View {
        modifier(CardStyle(padding: padding, background: background))
    }

    /// Keeps scroll content clear of the floating tab bar.
    func tabBarSafeArea() -> some View {
        safeAreaInset(edge: .bottom) { Color.clear.frame(height: 92) }
    }

    /// Standard canvas background for forms.
    func formCanvas() -> some View {
        scrollContentBackground(.hidden).background(Theme.canvas.ignoresSafeArea())
    }
}

// MARK: - Typography helpers

struct Eyebrow: View {
    let text: LocalizedStringKey
    var color: Color = Theme.inkTertiary

    init(_ text: LocalizedStringKey, color: Color = Theme.inkTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.3)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.display(22))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Badges

struct IconBadge: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
    }
}

struct StatusPill: View {
    let text: LocalizedStringResource
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy))
            .tracking(1)
            .foregroundStyle(Theme.forestDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                LinearGradient(colors: [Color(hex: 0xF3D38A), Color(hex: 0xE9A46B)], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var foreground: Color = Theme.canvas

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(configuration.isPressed ? 0.22 : 0.13), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Chips

struct ChoiceChip: View {
    let title: LocalizedStringResource
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(title).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? Theme.canvas : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Theme.ink : Theme.surfaceMuted, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: isSelected)
    }
}

/// Wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            width = max(width, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: Theme.inkSecondary, size: 54)
            Text(title)
                .font(.display(19))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(SoftButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

// MARK: - Premium lock

struct PremiumLockOverlay: ViewModifier {
    let isLocked: Bool
    let feature: PremiumFeature
    @Environment(StoreManager.self) private var store

    func body(content: Content) -> some View {
        content
            .blur(radius: isLocked ? 7 : 0)
            .allowsHitTesting(!isLocked)
            .overlay {
                if isLocked {
                    Button { store.presentPaywall(feature) } label: {
                        VStack(spacing: 8) {
                            PremiumBadge()
                            Text(feature.title)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            Text("Unlock with Premium")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
    }
}

extension View {
    func premiumLocked(_ isLocked: Bool, feature: PremiumFeature) -> some View {
        modifier(PremiumLockOverlay(isLocked: isLocked, feature: feature))
    }
}

// MARK: - Labeled value row

struct InfoRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let value: String
    var tint: Color = Theme.inkSecondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
                Text(value.isEmpty ? "—" : value)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
    }
}

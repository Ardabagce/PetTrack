import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// "Linen & Forest" — warm paper neutrals, deep forest ink and a terracotta accent.
enum Theme {
    static let canvas = Color(light: 0xF4EFE7, dark: 0x0E1311)
    static let surface = Color(light: 0xFFFDF9, dark: 0x171E1B)
    static let surfaceMuted = Color(light: 0xEBE4D8, dark: 0x222B27)
    static let ink = Color(light: 0x17201C, dark: 0xF1ECE3)
    static let inkSecondary = Color(light: 0x5D6962, dark: 0xA2ADA6)
    static let inkTertiary = Color(light: 0x97A099, dark: 0x6E7973)
    static let hairline = Color(light: 0xE3DBCE, dark: 0x2A3430)

    static let accent = Color(light: 0xCF5F3B, dark: 0xEE875F)
    static let sage = Color(light: 0x5A8A6E, dark: 0x86B596)
    static let butter = Color(light: 0xD39E2F, dark: 0xF0C463)
    static let sky = Color(light: 0x4C7FAB, dark: 0x7FAAD3)
    static let plum = Color(light: 0x83609F, dark: 0xB096CF)
    static let danger = Color(light: 0xBC3E33, dark: 0xEC6A5D)

    /// Fixed deep tones used on hero cards in both appearances.
    static let forest = Color(hex: 0x1D3529)
    static let forestDeep = Color(hex: 0x12231B)
    static let cream = Color(hex: 0xF6F0E4)

    static let petPalette: [Color] = [accent, sage, sky, plum, butter]

    static func petColor(_ index: Int) -> Color {
        petPalette[abs(index) % petPalette.count]
    }

    enum Radius {
        static let card: CGFloat = 26
        static let medium: CGFloat = 18
        static let small: CGFloat = 12
    }

    static func color(for category: ExpenseCategory) -> Color {
        switch category {
        case .vet: accent
        case .food: butter
        case .medication: plum
        case .insurance: sky
        case .grooming: sage
        case .supplies: Color(light: 0x8C7A5B, dark: 0xBCA987)
        case .other: inkTertiary
        }
    }

    static func color(for kind: FeedingKind) -> Color {
        switch kind {
        case .meal: butter
        case .water: sky
        case .treat: plum
        }
    }

    static func color(for status: VaccineStatus) -> Color {
        switch status {
        case .upToDate: sage
        case .dueSoon: butter
        case .overdue: danger
        }
    }
}

extension Font {
    /// Editorial serif used for titles and hero numbers.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

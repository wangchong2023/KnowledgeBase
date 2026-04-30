import SwiftUI

// MARK: - Wiki Accent Color Environment Key
private struct WikiAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.blue
}

extension EnvironmentValues {
    /// The current wiki accent color, propagated through the SwiftUI environment.
    /// Updated by KMApp whenever the user changes the theme color.
    var wikiAccentColor: Color {
        get { self[WikiAccentColorKey.self] }
        set { self[WikiAccentColorKey.self] = newValue }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Knowledge Base Color Palette
extension Color {
    // Adaptive colors that respond to light/dark mode
    static let wikiBackground = Color(
        light: Color(hex: "f5f5fa"),
        dark: Color(hex: "1a1b2e")
    )
    static let wikiCard = Color(
        light: Color(hex: "ffffff"),
        dark: Color(hex: "252640")
    )

    // Dynamic accent color: reads from ThemeManager's cached value.
    // Uses the shared ThemeManager singleton for consistency and caching.
    // Views should prefer @Environment(\.wikiAccentColor) for the best performance.
    static var wikiAccent: Color {
        ThemeManager.shared.accentColor
    }

    static let wikiText = Color(
        light: Color(hex: "1a1a2e"),
        dark: Color(hex: "e8e8f0")
    )
    static let wikiSecondary = Color(
        light: Color(hex: "6b6b87"),
        dark: Color(hex: "8b8ba7")
    )
    static let wikiBorder = Color(
        light: Color(hex: "e0e0ea"),
        dark: Color(hex: "3a3a5c")
    )
    static let wikiEntity = Color(
        light: Color(hex: "3a8aee"),
        dark: Color(hex: "4a9eff")
    )
    static let wikiConcept = Color(
        light: Color(hex: "9a4ee6"),
        dark: Color(hex: "b46eff")
    )
    static let wikiSource = Color(
        light: Color(hex: "3ab8b0"),
        dark: Color(hex: "4ecdc4")
    )
    static let wikiComparison = Color(
        light: Color(hex: "ee8a30"),
        dark: Color(hex: "ff9f43")
    )
    static let wikiMap = Color(
        light: Color(hex: "ee5555"),
        dark: Color(hex: "ff6b6b")
    )
    static let wikiRaw = Color(
        light: Color(hex: "7a8a8c"),
        dark: Color(hex: "95a5a6")
    )

    // Adaptive initializer
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Page Type Color Helper
extension PageType {
    var themedColor: Color {
        switch self {
        case .entity: return .wikiEntity
        case .concept: return .wikiConcept
        case .source: return .wikiSource
        case .comparison: return .wikiComparison
        case .map: return .wikiMap
        case .raw: return .wikiRaw
        }
    }
}

// MARK: - View Extension for Adaptive Backgrounds
extension View {
    func wikiAdaptiveBackground() -> some View {
        self.background(Color.wikiBackground)
    }
}

// MARK: - ShapeStyle Extension for Color Access
// Allows .foregroundStyle(.wikiText) syntax
extension ShapeStyle where Self == Color {
    static var wikiBackground: Color { Color.wikiBackground }
    static var wikiCard: Color { Color.wikiCard }
    static var wikiAccent: Color { Color.wikiAccent }
    static var wikiText: Color { Color.wikiText }
    static var wikiSecondary: Color { Color.wikiSecondary }
    static var wikiBorder: Color { Color.wikiBorder }
    static var wikiEntity: Color { Color.wikiEntity }
    static var wikiConcept: Color { Color.wikiConcept }
    static var wikiSource: Color { Color.wikiSource }
    static var wikiComparison: Color { Color.wikiComparison }
    static var wikiMap: Color { Color.wikiMap }
    static var wikiRaw: Color { Color.wikiRaw }
}

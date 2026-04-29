import SwiftUI

// MARK: - Wiki UI Constants
/// Centralized UI design constants to replace hard-coded values across the codebase.
enum WikiUI {
    /// Corner radius
    static let cardRadius: CGFloat = 12        // 通用卡片、Section
    static let standardRadius: CGFloat = 10     // 按钮、输入框、列表项
    static let smallRadius: CGFloat = 8        // 小型标签、小卡片
    static let mediumRadius: CGFloat = 14      // 聊天气泡
    static let largeRadius: CGFloat = 16       // 大型模态框
    static let chipRadius: CGFloat = 20       // 胶囊形标签
    static let microRadius: CGFloat = 6       // 紧凑标签、小块
    static let tinyRadius: CGFloat = 5        // 图标选择器芯片
    static let inlineRadius: CGFloat = 4     // 行内代码块
    static let hairlineRadius: CGFloat = 2    // 分隔线
    static let sidebarRadius: CGFloat = 7     // 侧边栏行

    /// Padding
    static let cardPadding: CGFloat = 16
    static let sectionPadding: CGFloat = 12
    static let tightPadding: CGFloat = 8

    /// Animation
    static let standardAnimation: Animation = .easeInOut(duration: 0.25)
    static let quickAnimation: Animation = .easeInOut(duration: 0.15)

    /// Icon sizes
    static let largeIconSize: CGFloat = 48
    static let titleIconSize: CGFloat = 24
    static let captionIconSize: CGFloat = 16
}

// MARK: - Color Scheme Mode
enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return L.tr("settings.theme.system")
        case .light: return L.tr("settings.theme.light")
        case .dark: return L.tr("settings.theme.dark")
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Accent Color Environment Key
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

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("colorSchemeMode") var colorSchemeModeRaw: String = ColorSchemeMode.dark.rawValue {
        willSet { objectWillChange.send() }
    }
    @AppStorage("accentColor") var accentColorRaw: String = "blue" {
        willSet {
            objectWillChange.send()
            // Invalidate cached Color so accessor returns the new value
            _cachedAccentColor = nil
        }
    }

    /// Cached Color value invalidated on every accentColorRaw change.
    private var _cachedAccentColor: Color?

    /// Migrate legacy isDarkMode key on first access
    private static var didMigrate = false

    var colorSchemeMode: ColorSchemeMode {
        get {
            if !Self.didMigrate {
                Self.didMigrate = true
                // Migrate: if old key exists and new key is default
                if UserDefaults.standard.object(forKey: "isDarkMode") != nil,
                   UserDefaults.standard.string(forKey: "colorSchemeMode") == nil {
                    let wasDark = UserDefaults.standard.bool(forKey: "isDarkMode")
                    colorSchemeModeRaw = wasDark ? ColorSchemeMode.dark.rawValue : ColorSchemeMode.light.rawValue
                    UserDefaults.standard.removeObject(forKey: "isDarkMode")
                }
            }
            return ColorSchemeMode(rawValue: colorSchemeModeRaw) ?? .dark
        }
        set {
            colorSchemeModeRaw = newValue.rawValue
        }
    }

    /// Cached computed property – reads from UserDefaults once, then caches
    /// until accentColorRaw changes and invalidates the cache.
    var accentColor: Color {
        if let cached = _cachedAccentColor {
            return cached
        }
        let color = ThemeManager.colorForName(accentColorRaw)
        _cachedAccentColor = color
        return color
    }

    func setAccentColor(_ color: String) {
        accentColorRaw = color
    }

    /// Maps a color name string (stored in UserDefaults) to a system Color.
    static func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
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

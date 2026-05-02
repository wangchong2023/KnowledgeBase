import SwiftUI

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("colorSchemeMode") var colorSchemeModeRaw: String = ColorSchemeMode.dark.rawValue
    @AppStorage("accentColor") var accentColorRaw: String = "blue"

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

    /// Live color: reads from UserDefaults on every access (no cache).
    /// @AppStorage already handles observation via Combine.
    var accentColor: Color {
        ThemeManager.colorForName(accentColorRaw)
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

    /// Instance method wrapper for convenience.
    func colorForName(_ name: String) -> Color {
        Self.colorForName(name)
    }
}

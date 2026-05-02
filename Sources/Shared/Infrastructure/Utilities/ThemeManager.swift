import SwiftUI

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("colorSchemeMode") var colorSchemeModeRaw: String = ColorSchemeMode.dark.rawValue
    nonisolated var accentColorRaw: String {
        get { UserDefaults.standard.string(forKey: "accentColor") ?? "blue" }
    }

    /// Migrate legacy isDarkMode key on first access
    private nonisolated(unsafe) static var didMigrate = false

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
    nonisolated var accentColor: Color {
        ThemeManager.colorForName(accentColorRaw)
    }

    func setAccentColor(_ color: String) {
        UserDefaults.standard.set(color, forKey: "accentColor")
        objectWillChange.send()
    }

    /// Maps a color name string (stored in UserDefaults) to a system Color.
    nonisolated static func colorForName(_ name: String) -> Color {
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
    nonisolated func colorForName(_ name: String) -> Color {
        Self.colorForName(name)
    }
}

extension ThemeManager: @unchecked Sendable {}

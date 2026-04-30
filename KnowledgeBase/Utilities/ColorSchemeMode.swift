import SwiftUI

// MARK: - Color Scheme Mode
enum ColorSchemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return Localized.tr("settings.theme.system")
        case .light: return Localized.tr("settings.theme.light")
        case .dark: return Localized.tr("settings.theme.dark")
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

import Foundation

// MARK: - Language Mode
/// 语言偏好选项
enum LanguageMode: String, CaseIterable {
    case system
    case chinese
    case english

    var displayName: String {
        switch self {
        case .system: return Localized.tr("settings.language.system")
        case .chinese: return Localized.tr("settings.language.chinese")
        case .english: return Localized.tr("settings.language.english")
        }
    }

    var icon: String {
        switch self {
        case .system: return "globe"
        case .chinese: return "character.book.closed"
        case .english: return "character.cursor.ibeam"
        }
    }
}

// MARK: - Localization Helper
/// String Catalog 原生支持的本地化系统.
/// 使用直接读取 .strings 文件的方式，确保能响应运行时语言切换.
enum Localized {

    // MARK: - Language Preference
    private static let languageModeKey = "km_language_mode"
    private static var languageModeRaw: String {
        get { UserDefaults.standard.string(forKey: languageModeKey) ?? LanguageMode.system.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: languageModeKey) }
    }

    static var languageMode: LanguageMode {
        get { LanguageMode(rawValue: languageModeRaw) ?? .system }
        set {
            languageModeRaw = newValue.rawValue
            // Update AppleLanguages to trigger language change
            let preferred: String
            switch newValue {
            case .system:
                preferred = Locale.preferredLanguages.first ?? "en"
            case .chinese:
                preferred = "zh-Hans"
            case .english:
                preferred = "en"
            }
            UserDefaults.standard.set([preferred], forKey: "AppleLanguages")
        }
    }

    static var currentLanguage: String {
        // 优先读 UserDefaults 中的 AppleLanguages（用户手动设置的语言）
        if let appleLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages"),
           let preferred = appleLanguages.first {
            if preferred.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        }
        // 否则跟随系统
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") || preferred.hasPrefix("zh_Hans") {
            return "zh-Hans"
        }
        return "en"
    }

    static var isChinese: Bool { currentLanguage == "zh-Hans" }

    // MARK: - Translation
    /// 动态读取 .strings 文件，确保能响应运行时语言切换
    static func tr(_ key: String) -> String {
        let lang = currentLanguage
        // 直接从 bundle 路径读取 .strings 文件，绕过 Bundle 的缓存
        if let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(lang).lproj"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] {
            return dict[key] ?? key
        }
        return key
    }

    /// 使用 String Catalog 进行格式化翻译
    static func trf(_ key: String, _ args: CVarArg...) -> String {
        let template = tr(key)
        if args.isEmpty {
            return template
        }
        return String(format: template, arguments: args)
    }
}

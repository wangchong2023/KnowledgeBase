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
        case .system:  return "globe"                      // 跟随系统
        case .chinese: return "globe.asia.australia.fill"  // 简体中文
        case .english: return "globe.americas.fill"        // English
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
            
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            } else {
                let preferred = (newValue == .chinese) ? "zh-Hans" : "en"
                UserDefaults.standard.set([preferred], forKey: "AppleLanguages")
            }
            
            // 立即刷新提示词服务
            PromptService.shared.updateLocalizables()
        }
    }

    static var currentLanguage: String {
        // 如果设置为跟随系统，或者没有 AppleLanguages 覆盖，则读取系统首选语言
        if languageMode == .system || UserDefaults.standard.stringArray(forKey: "AppleLanguages") == nil {
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        }
        
        // 读取手动覆盖的语言
        if let appleLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages"),
           let preferred = appleLanguages.first {
            if preferred.hasPrefix("zh") {
                return "zh-Hans"
            }
        }
        return "en"
    }

    static var isChinese: Bool { currentLanguage == "zh-Hans" }

    // MARK: - Translation
    /// 动态读取 .strings 文件，确保能响应运行时语言切换
    static func tr(_ key: String) -> String {
        let lang = currentLanguage
        
        // 尝试加载对应语言的 Bundle 以支持运行时语言切换
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, bundle: bundle, comment: "")
        }
        
        // Fallback 到标准方式
        return NSLocalizedString(key, comment: "")
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

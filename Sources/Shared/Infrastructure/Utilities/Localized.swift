// Localized.swift
//
// 作者: Wang Chong
// 功能说明: 语言偏好选项
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

// MARK: - Language Mode
/// 语言偏好选项
enum LanguageMode: String, CaseIterable {
    case system
    case chinese
    case english

    var displayName: String {
        switch self {
        case .system: return L10n.Settings.tr("language.system")
        case .chinese: return L10n.Settings.tr("language.chinese")
        case .english: return L10n.Settings.tr("language.english")
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
    /// - Parameters:
    ///   - key: 本地化 Key
    ///   - table: 所在的 .strings / .xcstrings 文件名 (默认为 Localizable)
    static func tr(_ key: String, table: String? = nil) -> String {
        let lang = currentLanguage
        
        let result: String
        // 尝试加载对应语言的 Bundle 以支持运行时语言切换
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            result = NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
        } else {
            // Fallback 到标准方式
            result = NSLocalizedString(key, tableName: table, value: key, comment: "")
        }
        
        // --- 修复逻辑：如果指定的 table 中找不到 (返回了 key 本身)，尝试从默认 Localizable 中找 ---
        if result == key && table != nil && table != "Localizable" {
            let fallbackResult: String
            if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                fallbackResult = NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
            } else {
                fallbackResult = NSLocalizedString(key, tableName: "Localizable", value: key, comment: "")
            }
            if fallbackResult != key {
                return fallbackResult
            }
        }
        
        #if DEBUG
        if result == key && !key.isEmpty && key.contains(".") {
            // 如果返回结果等于 key，通常意味着该 table 中没有对应的翻译条目
            let message = "⚠️ [Localization] Missing key: '\(key)' in table: '\(table ?? "Localizable")'"
            print(message)
            // 返回带标记的字符串以便在 UI 中识别，但不崩溃
            return "[MISSING: \(key)]"
        }
        #endif
        
        return result
    }

    /// 使用 String Catalog 进行格式化翻译
    /// - Parameters:
    ///   - key: 本地化 Key
    ///   - table: 所在的 .strings / .xcstrings 文件名 (默认为 Localizable)
    ///   - args: 格式化参数
    static func trf(_ key: String, table: String? = nil, _ args: CVarArg...) -> String {
        let template = tr(key, table: table ?? "Localizable")
        if args.isEmpty {
            return template
        }
        return String(format: template, arguments: args)
    }
}

// MARK: - Type-Safe Localization
/// 强类型本地化常量访问器
struct L10n {
    /// 图谱模块
    struct Graph {
        static func tr(_ key: String) -> String { Localized.tr("graph.\(key)", table: "Graph") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }

        static var title: String { tr("title") }
        static var optimizingLayout: String { tr("optimizingLayout") }
        static var insights: String { tr("insights") }
        static var legend: String { tr("legend") }
        
        struct ThreeD {
            static func tr(_ key: String) -> String { Localized.tr("graph3d.\(key)", table: "Graph") }
        }
    }
    
    /// 设置模块
    struct Settings {
        static func tr(_ key: String) -> String { Localized.tr("settings.\(key)", table: "Settings") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }

        static var title: String { tr("settings") }
        static var systemLanguage: String { tr("systemLanguage") }
        static var version: String { tr("version") }
        static var about: String { tr("aboutApp") }
        static var privacyMode: String { tr("privacyMode") }
        static var security: String { tr("section.security") }
        static var accentColor: String { tr("accentColor") }
        
        struct Section {
            static var ai: String { Settings.tr("section.ai") }
            static var data: String { Settings.tr("section.data") }
            static var security: String { Settings.tr("section.security") }
            static var danger: String { Settings.tr("section.danger") }
        }
    }
    
    /// AI 智能化模块
    struct AI {
        static func tr(_ key: String) -> String { Localized.tr("ai.\(key)", table: "AITasks") }
        
        /// 运行时状态反馈
        struct Status {
            static var analyzing: String { AI.tr("status.analyzing") }
            static var preprocessing: String { AI.tr("status.preprocessing") }
            static var scanning: String { AI.tr("status.scanning") }
            static var thinking: String { AI.tr("status.thinking") }
        }
        
        /// 任务中心 (AITask 前缀)
        struct Task {
            static func tr(_ key: String) -> String { Localized.tr("aitask.\(key)", table: "AITasks") }
            static func trf(_ key: String, _ args: CVarArg...) -> String {
                let template = tr(key)
                return String(format: template, arguments: args)
            }

            static var centerTitle: String { tr("center.title") }
            static var emptyTitle: String { tr("empty.title") }
            static var emptyDesc: String { tr("empty.desc") }
            static var clearAll: String { tr("clearAll") }
            
            struct TypeName {
                static var aiScan: String { Task.tr("type.aiScan") }
                static var healthCheck: String { Task.tr("type.healthCheck") }
                static var synthesis: String { Task.tr("type.synthesis") }
            }
        }
    }
    
    /// 备份模块
    struct Backup {
        static func tr(_ key: String) -> String { Localized.tr("backup.\(key)", table: "Backup") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }
        
        static var title: String { tr("title") }
    }
    
    /// 导入模块
    struct Ingest {
        static func tr(_ key: String) -> String { Localized.tr("ingest.\(key)", table: "Ingest") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }
        
        static var title: String { tr("title") }
    }
    
    /// 通用操作
    struct Action {
        static func tr(_ key: String) -> String { Localized.tr("action.\(key)", table: "Actions") }
        
        static var createPage: String { tr("createPage") }
        static var browseGraph: String { tr("browseGraph") }
        static var ingestKnowledge: String { tr("ingestKnowledge") }
    }
    
    /// 公共词条
    struct Common {
        static func tr(_ key: String) -> String { Localized.tr("misc.\(key)", table: "Common") }
        
        static var ok: String { tr("ok") }
        static var cancel: String { tr("cancel") }
        static var done: String { tr("done") }
        static var delete: String { tr("delete") }
        static var save: String { tr("save") }
        static var edit: String { tr("edit") }
        static var view: String { tr("view") }
        
        struct Empty {
            static func tr(_ key: String) -> String { Localized.tr("empty.\(key)", table: "Common") }
        }
    }
    
    /// 无障碍
    struct Accessibility {
        static func tr(_ key: String) -> String { Localized.tr("a11y.\(key)", table: "Accessibility") }
        
        static var links: String { tr("links") }
    }
    
    /// 聊天模块
    struct Chat {
        static func tr(_ key: String) -> String { Localized.tr("chat.\(key)", table: "Chat") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }
        
        static var title: String { tr("title") }
    }
    
    /// UI 组件
    struct Components {
        static func tr(_ key: String) -> String { Localized.tr("backlinks.\(key)", table: "Components") }
        
        struct Backlinks {
            static var noOutgoing: String { Components.tr("noOutgoing") }
            static var noBackLinks: String { Components.tr("noBackLinks") }
        }
    }
    
    /// 手表端
    struct Watch {
        static func tr(_ key: String) -> String { Localized.tr("watch.\(key)", table: "Watch") }
    }
    
    /// 页面架构
    struct Schema {
        static func tr(_ key: String) -> String { Localized.tr("schema.\(key)", table: "Schema") }
    }
    
    /// 核心模型词条
    struct CoreModels {
        static func tr(_ key: String) -> String { Localized.tr(key, table: "CoreModels") }
        
        struct TypeName {
            static func tr(_ key: String) -> String { CoreModels.tr("type.\(key)") }
        }
        struct Status {
            static func tr(_ key: String) -> String { CoreModels.tr("status.\(key)") }
        }
    }
    
    /// 协作模块
    struct Collaboration {
        static func tr(_ key: String) -> String { Localized.tr("collab.\(key)", table: "Collaboration") }
    }
    
    /// 小组件
    struct Widget {
        static func tr(_ key: String) -> String { Localized.tr("widget.\(key)", table: "Widget") }
    }
    
    /// 数据流转 (导入/导出)
    struct Transfer {
        static func tr(_ key: String) -> String { Localized.tr(key, table: "Transfer") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }
        
        struct Export {
            static func tr(_ key: String) -> String { Transfer.tr("export.\(key)") }
            static func trf(_ key: String, _ args: CVarArg...) -> String {
                let template = tr(key)
                return String(format: template, arguments: args)
            }
        }
        struct Import {
            static func tr(_ key: String) -> String { Transfer.tr("import.\(key)") }
            static func trf(_ key: String, _ args: CVarArg...) -> String {
                let template = tr(key)
                return String(format: template, arguments: args)
            }
        }
    }
    
    /// 新手指引
    struct Coachmark {
        static func tr(_ key: String) -> String { Localized.tr("coachmark.\(key)", table: "Coachmark") }
    }
    
    /// 创建流程
    struct Creation {
        static func tr(_ key: String) -> String { Localized.tr("create.\(key)", table: "Creation") }
    }
    
    /// 仪表盘
    struct Dashboard {
        static func tr(_ key: String) -> String { Localized.tr("dashboard.\(key)", table: "Dashboard") }
    }
    
    /// 编辑器
    struct Editor {
        static func tr(_ key: String) -> String { Localized.tr("editor.\(key)", table: "Editor") }
    }
    
    /// iCloud 同步
    struct ICloud {
        static func tr(_ key: String) -> String { Localized.tr("icloud.\(key)", table: "ICloud") }
    }
    
    /// 内容巡检 (Lint)
    struct Lint {
        static func tr(_ key: String) -> String { Localized.tr("lint.\(key)", table: "Lint") }
        static func trf(_ key: String, _ args: CVarArg...) -> String {
            let template = tr(key)
            return String(format: template, arguments: args)
        }
    }
}

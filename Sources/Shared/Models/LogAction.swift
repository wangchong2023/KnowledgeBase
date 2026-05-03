import SwiftUI

/// 操作日志动作类型 (Product Manager 视角：标准化的动作分类，驱动 UI 表现)
enum LogAction: String, Codable, CaseIterable {
    // 核心创作
    case create = "logAction.create"
    case update = "logAction.update"
    case delete = "logAction.delete"
    
    // 数据管理
    case ingest = "logAction.ingest"
    case smartIngest = "logAction.smartIngest"
    case export = "action.export"
    
    // PDF 增强
    case importPDF = "logAction.importPDF"
    case importPDFFailed = "logAction.importPDFFailed"
    case deletePDF = "logAction.deletePDF"
    case highlight = "logAction.highlight"
    
    // 系统与 AI
    case lint = "logAction.lint"
    case healthCheck = "logAction.healthCheck"
    case systemInit = "logAction.systemInit"
    case aiscanFailed = "log.action.aiscan.failed"
    case aiscanSkipped = "log.action.aiscan.skipped"
    
    // 系统级
    case error = "ERROR"
    case unknown = "unknown"

    /// 本地化显示名称
    var localizedName: String {
        Localized.tr(self.rawValue)
    }
    
    /// 动作对应的品牌色
    var color: Color {
        switch self {
        case .create: return .green
        case .update: return .blue
        case .delete, .deletePDF, .importPDFFailed, .aiscanFailed: return .red
        case .lint, .healthCheck: return .orange
        case .ingest, .importPDF, .export: return .wikiSource
        case .smartIngest: return .wikiAccent
        case .systemInit: return .purple
        case .aiscanSkipped: return .wikiSecondary
        case .highlight: return .wikiAccent
        default: return .wikiSecondary
        }
    }
    
    /// 动作对应的 SF Symbol 图标
    var icon: String {
        switch self {
        case .create: return "plus"
        case .update: return "pencil"
        case .delete, .deletePDF: return "trash"
        case .lint, .healthCheck: return "stethoscope"
        case .ingest, .importPDF, .export: return "arrow.down.doc"
        case .smartIngest: return "sparkles"
        case .highlight: return "highlighter"
        case .systemInit: return "sparkles"
        case .aiscanFailed, .importPDFFailed: return "exclamationmark.triangle"
        case .aiscanSkipped: return "forward.end"
        default: return "circle"
        }
    }
}

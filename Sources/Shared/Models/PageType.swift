// PageType.swift
//
// 作者: Wang Chong
// 功能说明: enum PageType
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import GRDB

// MARK: - Page Type
enum PageType: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    case entity = "entity"
    case concept = "concept"
    case source = "source"
    case comparison = "comparison"
    case map = "map"
    case raw = "raw"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .entity: return L10n.CoreModels.tr("type.entity")
        case .concept: return L10n.CoreModels.tr("type.concept")
        case .source: return L10n.CoreModels.tr("type.source")
        case .comparison: return L10n.CoreModels.tr("type.comparison")
        case .map: return L10n.CoreModels.tr("type.map")
        case .raw: return L10n.CoreModels.tr("type.raw")
        }
    }
    
    var icon: String {
        switch self {
        case .entity: return "person.text.rectangle.fill"
        case .concept: return "lightbulb.fill"
        case .source: return "doc.richtext.fill"
        case .comparison: return "arrow.left.arrow.right.circle.fill"
        case .map: return "map.fill"
        case .raw: return "doc.plaintext.fill"
        }
    }
    
    var color: String {
        switch self {
        case .entity: return "blue"
        case .concept: return "purple"
        case .source: return "green"
        case .comparison: return "orange"
        case .map: return "red"
        case .raw: return "gray"
        }
    }
}

// MARK: - Page Status
enum PageStatus: String, Codable, CaseIterable, DatabaseValueConvertible {
    case active = "active"
    case stub = "stub"
    case needsUpdate = "needs-update"
    case deprecated = "deprecated"
    
    var displayName: String {
        switch self {
        case .active: return L10n.CoreModels.tr("status.active")
        case .stub: return L10n.CoreModels.tr("status.stub")
        case .needsUpdate: return L10n.CoreModels.tr("status.needsUpdate")
        case .deprecated: return L10n.CoreModels.tr("status.deprecated")
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .stub: return .yellow
        case .needsUpdate: return .orange
        case .deprecated: return .red
        }
    }

}

// MARK: - Confidence Level
enum Confidence: String, Codable, CaseIterable, DatabaseValueConvertible {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return L10n.CoreModels.tr("confidence.high")
        case .medium: return L10n.CoreModels.tr("confidence.medium")
        case .low: return L10n.CoreModels.tr("confidence.low")
        }
    }

    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .red
        }
    }

}

// PageSchema.swift
//
// 作者: Wang Chong
// 功能说明: 页面 Schema：定义特定类型页面必须包含的内容结构
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 页面 Schema：定义特定类型页面必须包含的内容结构
@MainActor
struct PageSchema: Codable {
    let type: PageType
    let requiredFields: [String]
    let template: String
    let promptInstruction: String
}

final class SchemaService {
    nonisolated(unsafe) static let shared = SchemaService()
    
    var schemas: [PageType: PageSchema] = [
        .entity: PageSchema(
            type: .entity,
            requiredFields: [
                L10n.Schema.tr("entity.field.definition"),
                L10n.Schema.tr("entity.field.attributes"),
                L10n.Schema.tr("entity.field.relations")
            ],
            template: L10n.Schema.tr("entity.template"),
            promptInstruction: L10n.Schema.tr("entity.prompt")
        ),
        .concept: PageSchema(
            type: .concept,
            requiredFields: [
                L10n.Schema.tr("concept.field.theory"),
                L10n.Schema.tr("concept.field.applications")
            ],
            template: L10n.Schema.tr("concept.template"),
            promptInstruction: L10n.Schema.tr("concept.prompt")
        )
    ]
    
    func schema(for type: PageType) -> PageSchema? {
        schemas[type]
    }
}

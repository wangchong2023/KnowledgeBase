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
                Localized.tr("schema.entity.field.definition"),
                Localized.tr("schema.entity.field.attributes"),
                Localized.tr("schema.entity.field.relations")
            ],
            template: Localized.tr("schema.entity.template"),
            promptInstruction: Localized.tr("schema.entity.prompt")
        ),
        .concept: PageSchema(
            type: .concept,
            requiredFields: [
                Localized.tr("schema.concept.field.theory"),
                Localized.tr("schema.concept.field.applications")
            ],
            template: Localized.tr("schema.concept.template"),
            promptInstruction: Localized.tr("schema.concept.prompt")
        )
    ]
    
    func schema(for type: PageType) -> PageSchema? {
        schemas[type]
    }
}

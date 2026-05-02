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
    static let shared = SchemaService()
    
    var schemas: [PageType: PageSchema] = [
        .entity: PageSchema(
            type: .entity,
            requiredFields: ["定义", "核心属性", "关联实体"],
            template: "# {title}\n\n## 定义\n{definition}\n\n## 核心属性\n- 属性1: \n- 属性2: \n\n## 关联实体\n- [[相关实体]]",
            promptInstruction: "对于实体类型，必须提取其明确的定义，并列出至少3个核心属性。必须发现并建立与其他实体的双向链接。"
        ),
        .concept: PageSchema(
            type: .concept,
            requiredFields: ["原理", "应用场景"],
            template: "# {title}\n\n## 原理\n{theory}\n\n## 应用场景\n- 场景1\n- 场景2",
            promptInstruction: "对于概念类型，重点解释其底层原理和实际应用场景。内容要求高度概括且专业。"
        )
    ]
    
    func schema(for type: PageType) -> PageSchema? {
        schemas[type]
    }
}

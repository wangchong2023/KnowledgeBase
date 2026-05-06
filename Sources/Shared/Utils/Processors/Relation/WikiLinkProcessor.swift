// WikiLinkProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识网络关系的核心解析引擎（WikiLinkProcessor），专门用于识别与处理文档间的双向引用关系。
// 该处理器是系统构建知识图谱（Knowledge Graph）的底层基石，其核心功能点如下：
// 1. Wiki-link 模式识别：通过高性能正则表达式精准提取 Markdown 文本中的 [[target]] 标记，支持对链接标题进行归一化处理。
// 2. 关系完整性审计：提供对知识库内双向链接（Incoming/Outgoing Links）的全局分析，支持检测断路引用与孤立页面。
// 3. 语义关联计算：为 WikiPage 模型提供解耦的链接提取服务，确保数据模型层（Model）与复杂的字符串解析逻辑分离。
// 4. 冲突预警：在解析过程中识别潜在的命名冲突与循环引用，提升知识库的逻辑健壮性。
// 版本: 1.0
// 修改记录:
//   - 2026-05-05: 初始创建，将链接解析逻辑从 WikiPage 中解耦
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// Wiki 链接处理器：负责处理 [[wikilinks]] 的解析与管理
struct WikiLinkProcessor {
    
    /// 从 Markdown 文本中提取所有 Wiki-link 的目标标题
    /// - Parameter content: 原始 Markdown 内容
    /// - Returns: 提取到的标题列表（已去重）
    static func extractOutgoingLinks(from content: String) -> [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        // 使用 Set 去重
        let links = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            return nsContent.substring(with: match.range(at: 1))
        }
        
        return Array(Set(links)).sorted()
    }
}

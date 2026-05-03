import Foundation

// MARK: - LLM Context Builder
/// 构建系统提示词并为 LLM 查询检索相关知识库上下文。
final class LLMContextBuilder {
    
    // MARK: - Configuration Constants
    /// Max entities listed in the system prompt overview.
    private static let maxEntityOverview = 20
    /// Max concepts listed in the system prompt overview.
    private static let maxConceptOverview = 20
    /// Max sources listed in the system prompt overview.
    private static let maxSourceOverview = 10
    /// Max recent pages shown in the system prompt overview.
    private static let maxRecentOverview = 5
    /// Content preview length per page in system prompt.
    private static let contentPreviewLength = 100
    /// Max pages included in the relevant context for a query.
    private static let maxContextPages = 10
    /// Content preview length per page in query context.
    private static let contextPreviewLength = 500
    
    // MARK: - System Prompt
    func buildSystemPrompt(pages: [WikiPage]) -> String {
        var prompt = """
        \(Localized.tr("llm.prompt.role"))
        
        \(Localized.tr("chat.welcomeDesc"))：
        \(Localized.tr("llm.prompt.duty1"))
        \(Localized.tr("llm.prompt.duty2"))
        \(Localized.tr("llm.prompt.duty3"))
        \(Localized.tr("llm.prompt.duty4"))
        
        \(Localized.tr("ingest.compileRules"))
        \(Localized.tr("llm.prompt.rule1"))
        \(Localized.tr("llm.prompt.rule2"))
        \(Localized.tr("llm.prompt.rule3"))
        \(Localized.tr("llm.prompt.rule4"))
        
        \(Localized.tr("llm.prompt.overview"))
        """
        
        // 总结知识库内容作为上下文
        let activePages = pages.filter { $0.status == .active || $0.status == .stub }
        let totalPages = activePages.count
        let entities = activePages.filter { $0.type == .entity }
        let concepts = activePages.filter { $0.type == .concept }
        let sources = activePages.filter { $0.type == .source }
        
        prompt += "\n- \(Localized.tr("llm.prompt.totalPages")): \(totalPages)"
        prompt += "\n- \(Localized.tr("llm.prompt.entityCount")): \(entities.count), \(Localized.tr("llm.prompt.conceptCount")): \(concepts.count), \(Localized.tr("llm.prompt.sourceCount")): \(sources.count)"
        prompt += "\n\n\(Localized.tr("llm.prompt.entityList"))"
        for entity in entities.prefix(Self.maxEntityOverview) {
            prompt += "\n- [[\(entity.title)]]: \(String(entity.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(Localized.tr("llm.prompt.conceptList"))"
        for concept in concepts.prefix(Self.maxConceptOverview) {
            prompt += "\n- [[\(concept.title)]]: \(String(concept.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(Localized.tr("llm.prompt.sourceList"))"
        for source in sources.prefix(Self.maxSourceOverview) {
            prompt += "\n- [[\(source.title)]]"
        }
        
        // Add recent changes
        let recent = activePages.sorted { $0.updated > $1.updated }.prefix(Self.maxRecentOverview)
        if !recent.isEmpty {
            prompt += "\n\n\(Localized.tr("llm.prompt.recentUpdates"))"
            for page in recent {
                prompt += "\n- \(page.title) (\(page.updated.formatted(.dateTime.month().day())))"
            }
        }
        
        return prompt
    }
    
    // MARK: - Context Retrieval (for query)
    /// Finds relevant pages for a given query using title/alias/tag/content matching + 1-hop link expansion.
    func buildRelevantContext(query: String, pages: [WikiPage]) -> String {
        var relevantPages: [WikiPage] = []
        
        // Find pages whose title or content is related to the query
        for page in pages {
            let titleMatch = page.title.localizedCaseInsensitiveContains(query) ||
                             query.localizedCaseInsensitiveContains(page.title) ||
                             page.aliases.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            let tagMatch = page.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            let contentMatch = page.content.localizedCaseInsensitiveContains(query)
            
            if titleMatch || tagMatch || contentMatch {
                relevantPages.append(page)
            }
        }
        
        // Also include pages linked from relevant pages (1 hop)
        var extendedIDs = Set(relevantPages.map(\.id))
        for page in relevantPages {
            for link in page.outgoingLinks {
                if let linked = pages.first(where: { $0.title == link }) {
                    extendedIDs.insert(linked.id)
                }
            }
        }
        let allRelevant = pages.filter { extendedIDs.contains($0.id) }
        
        var context = "\(Localized.tr("llm.prompt.relevantPages"))\n"
        for page in allRelevant.prefix(Self.maxContextPages) {
            context += "\n---\n## \(page.title)\n\(Localized.tr("llm.prompt.typeLabel")): \(page.type.displayName) | \(Localized.tr("llm.prompt.statusLabel")): \(page.status.displayName)\n\n"
            context += String(page.content.prefix(Self.contextPreviewLength))
            if page.content.count > Self.contextPreviewLength { context += "..." }
            context += "\n"
        }
        
        return context
    }
    
    // MARK: - Ingest Prompt Builder
    func buildIngestPrompt(title: String, rawContent: String, pages: [WikiPage]) -> String {
        let existingTitles = pages.map(\.title).joined(separator: ", ")
        
        return """
        \(Localized.tr("llm.ingest.compileInstruction"))
        
        \(Localized.tr("llm.ingest.compileRules"))
        \(Localized.tr("llm.ingest.rule1"))
        \(Localized.tr("llm.ingest.rule2"))
        \(Localized.tr("llm.ingest.rule3"))
        \(Localized.tr("llm.ingest.rule4"))
        \(Localized.tr("llm.ingest.rule5"))
        \(Localized.tr("llm.ingest.rule6"))
        
        \(Localized.tr("llm.ingest.existingPages"))：\(existingTitles)
        
        \(Localized.tr("llm.ingest.rawTitle"))：\(title)
        
        \(Localized.tr("llm.ingest.rawContent"))
        \(rawContent)
        
        ---
        ## 结构化规范 (Schema Rules)
        对于识别出的不同类型，请务必遵守以下内容结构和提取要求：
        
        1. **实体 (entity)**: 提取明确定义，列出核心属性。必须发现并建立与其他实体的双向链接。
        2. **概念 (concept)**: 重点解释底层原理和应用场景。内容要求高度概括且专业。
        
        请严格按照以下 JSON 格式输出结果：
        {
          "compiledContent": "\(Localized.tr("llm.ingest.jsonCompiledContent"))",
          "suggestedTags": ["\(Localized.tr("llm.ingest.jsonSuggestedTags"))1", "\(Localized.tr("llm.ingest.jsonSuggestedTags"))2"],
          "suggestedType": "entity|concept|source|comparison|map",
          "relatedTitles": [],
          "summary": "\(Localized.tr("llm.ingest.jsonSummary"))"
        }
        """
    }
    
    // MARK: - Query Rewrite Builder
    func buildRewritePrompt(query: String) -> String {
        """
        \(Localized.tr("prompt.queryRewrite.instruction"))
        
        \(Localized.tr("prompt.queryRewrite.rules"))
        1. \(Localized.tr("prompt.queryRewrite.rule1"))
        2. \(Localized.tr("prompt.queryRewrite.rule2"))
        3. \(Localized.tr("prompt.queryRewrite.rule3"))
        4. \(Localized.tr("prompt.queryRewrite.rule4"))
        
        \(Localized.tr("prompt.queryRewrite.userQuery")): \(query)
        
        \(Localized.tr("prompt.queryRewrite.footer"))
        """
    }
}

// MARK: - Chat History Store
/// Manages chat message persistence with UserDefaults.
final class ChatHistoryStore: ObservableObject {
    var messages: [ChatMessage] = []
    
    private let historyKey = "wikicraft_chat_history"
    
    init() {
        load()
    }
    
    func append(_ message: ChatMessage) {
        messages.append(message)
        persistToDisk()
    }
    
    func appendBatch(_ newMessages: [ChatMessage]) {
        messages.append(contentsOf: newMessages)
        persistToDisk()
    }
    
    func clear() {
        messages.removeAll()
        persistToDisk()
    }
    
    /// Explicitly persist current state to disk (public for external sync).
    func persistToDisk() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    /// Returns the last N messages (typically for LLM context window).
    func recent(_ count: Int) -> ArraySlice<ChatMessage> {
        messages.suffix(count)
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = history
        }
    }
}

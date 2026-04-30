import Foundation

// MARK: - LLM Context Builder
/// Builds system prompts and retrieves relevant wiki context for LLM queries.
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
        \(L.tr("llm.prompt.role"))
        
        \(L.tr("chat.welcomeDesc"))：
        \(L.tr("llm.prompt.duty1"))
        \(L.tr("llm.prompt.duty2"))
        \(L.tr("llm.prompt.duty3"))
        \(L.tr("llm.prompt.duty4"))
        
        \(L.tr("ingest.compileRules"))
        \(L.tr("llm.prompt.rule1"))
        \(L.tr("llm.prompt.rule2"))
        \(L.tr("llm.prompt.rule3"))
        \(L.tr("llm.prompt.rule4"))
        
        \(L.tr("llm.prompt.overview"))
        """
        
        // Summarize wiki content for context
        let activePages = pages.filter { $0.status == .active || $0.status == .stub }
        let totalPages = activePages.count
        let entities = activePages.filter { $0.type == .entity }
        let concepts = activePages.filter { $0.type == .concept }
        let sources = activePages.filter { $0.type == .source }
        
        prompt += "\n- \(L.tr("llm.prompt.totalPages")): \(totalPages)"
        prompt += "\n- \(L.tr("llm.prompt.entityCount")): \(entities.count), \(L.tr("llm.prompt.conceptCount")): \(concepts.count), \(L.tr("llm.prompt.sourceCount")): \(sources.count)"
        prompt += "\n\n\(L.tr("llm.prompt.entityList"))"
        for entity in entities.prefix(Self.maxEntityOverview) {
            prompt += "\n- [[\(entity.title)]]: \(String(entity.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(L.tr("llm.prompt.conceptList"))"
        for concept in concepts.prefix(Self.maxConceptOverview) {
            prompt += "\n- [[\(concept.title)]]: \(String(concept.content.prefix(Self.contentPreviewLength)))"
        }
        prompt += "\n\n\(L.tr("llm.prompt.sourceList"))"
        for source in sources.prefix(Self.maxSourceOverview) {
            prompt += "\n- [[\(source.title)]]"
        }
        
        // Add recent changes
        let recent = activePages.sorted { $0.updated > $1.updated }.prefix(Self.maxRecentOverview)
        if !recent.isEmpty {
            prompt += "\n\n\(L.tr("llm.prompt.recentUpdates"))"
            for page in recent {
                prompt += "\n- \(page.title) (\(page.updated.formatted(.dateTime.month().day())))"
            }
        }
        
        return prompt
    }
    
    // MARK: - Context Retrieval (for query)
    /// Finds relevant pages for a given query using title/alias/tag/content matching + 1-hop link expansion.
    func buildRelevantContext(query: String, pages: [WikiPage]) -> String {
        let queryLower = query.lowercased()
        var relevantPages: [WikiPage] = []
        
        // Find pages whose title or content is related to the query
        for page in pages {
            let titleMatch = queryLower.contains(page.title.lowercased()) ||
                             page.title.lowercased().contains(queryLower) ||
                             page.aliases.contains(where: { queryLower.contains($0.lowercased()) })
            let tagMatch = page.tags.contains(where: { queryLower.contains($0.lowercased()) })
            let contentMatch = page.content.lowercased().contains(queryLower)
            
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
        
        var context = "\(L.tr("llm.prompt.relevantPages"))\n"
        for page in allRelevant.prefix(Self.maxContextPages) {
            context += "\n---\n## \(page.title)\n\(L.tr("llm.prompt.typeLabel")): \(page.type.displayName) | \(L.tr("llm.prompt.statusLabel")): \(page.status.displayName)\n\n"
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
        \(L.tr("llm.ingest.compileInstruction"))
        
        \(L.tr("llm.ingest.compileRules"))
        \(L.tr("llm.ingest.rule1"))
        \(L.tr("llm.ingest.rule2"))
        \(L.tr("llm.ingest.rule3"))
        \(L.tr("llm.ingest.rule4"))
        \(L.tr("llm.ingest.rule5"))
        \(L.tr("llm.ingest.rule6"))
        
        \(L.tr("llm.ingest.existingPages"))：\(existingTitles)
        
        \(L.tr("llm.ingest.rawTitle"))：\(title)
        
        \(L.tr("llm.ingest.rawContent"))
        \(rawContent)
        
        \(L.tr("llm.ingest.jsonFormat"))
        {
          "compiledContent": "\(L.tr("llm.ingest.jsonCompiledContent"))",
          "suggestedTags": ["\(L.tr("llm.ingest.jsonSuggestedTags"))1", "\(L.tr("llm.ingest.jsonSuggestedTags"))2"],
          "suggestedType": "entity|concept|source|comparison|map",
          "relatedTitles": [],
          "summary": "\(L.tr("llm.ingest.jsonSummary"))"
        }
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

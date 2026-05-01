import Foundation

// MARK: - Link Service (Link Resolution + Search + Tags)
/// Handles link resolution, backlinks, search, and tag aggregation.
/// Stateless — operates on PageStore's pages array.
final class LinkService {
    
    // MARK: - Link Resolution
    func pageByTitle(_ title: String, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.title.lowercased() == title.lowercased() }
            ?? pages.first { $0.aliases.contains(where: { $0.lowercased() == title.lowercased() }) }
    }

    func backlinks(for pageID: UUID, in pages: [WikiPage]) -> [WikiPage] {
        guard let page = pages.first(where: { $0.id == pageID }) else { return [] }
        return pages.filter { p in
            p.outgoingLinks.contains(where: { link in
                link.lowercased() == page.title.lowercased() ||
                page.aliases.contains(where: { $0.lowercased() == link.lowercased() })
            })
        }
    }

    func pageByID(_ id: UUID, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.id == id }
    }

    // MARK: - Search
    func search(query: String, in pages: [WikiPage]) -> [WikiPage] {
        guard !query.isEmpty else { return pages }
        let q = query.lowercased()
        return pages.filter { page in
            page.title.lowercased().contains(q) ||
            page.content.lowercased().contains(q) ||
            page.tags.contains(where: { $0.lowercased().contains(q) }) ||
            page.aliases.contains(where: { $0.lowercased().contains(q) })
        }
    }
    
        // 3. RRF 融合排序
        return rrf(keywordResults: keywordResults, semanticResults: semanticResults)
    }
    
    /// 混合检索（带诊断信息版）
    func hybridSearchWithDiagnostics(query: String, in pages: [WikiPage], embeddingManager: EmbeddingManager) -> (results: [WikiPage], diagnostics: [SearchDiagnosticInfo.ResultScore]) {
        let keywordResults = search(query: query, in: pages)
        let semanticScored = embeddingManager.search(query: query)
        let semanticResults = semanticScored.compactMap { res -> WikiPage? in
            pages.first { $0.id == res.id }
        }
        
        let k = 60
        var scores: [UUID: Double] = [:]
        var diagMap: [UUID: (fts: Int, vec: Int)] = [:]
        
        for (index, page) in keywordResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
            diagMap[page.id] = (index + 1, -1)
        }
        
        for (index, page) in semanticResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
            let existing = diagMap[page.id] ?? (-1, -1)
            diagMap[page.id] = (existing.fts, index + 1)
        }
        
        let sortedIDs = scores.keys.sorted { scores[$0]! > scores[$1]! }
        let results = sortedIDs.compactMap { id in pages.first { $0.id == id } }
        
        let diagnostics = results.prefix(10).map { page in
            let ranks = diagMap[page.id]!
            return SearchDiagnosticInfo.ResultScore(
                id: page.id,
                title: page.title,
                ftsRank: ranks.fts,
                vectorRank: ranks.vec,
                finalScore: scores[page.id]!
            )
        }
        
        return (results, diagnostics)
    }
    
    /// Reciprocal Rank Fusion (RRF) 算法
    /// 公式: score = sum(1 / (k + rank))
    private func rrf(keywordResults: [WikiPage], semanticResults: [WikiPage], k: Int = 60) -> [WikiPage] {
        var scores: [UUID: Double] = [:]
        
        // 为关键词结果打分
        for (index, page) in keywordResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
        }
        
        // 为语义结果打分 (累计)
        for (index, page) in semanticResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
        }
        
        // 合并去重并按 RRF 总分排序
        let sortedIDs = scores.keys.sorted { scores[$0]! > scores[$1]! }
        
        // 将 ID 映射回 WikiPage 对象（从全集中查找以保持引用一致）
        let allCandidates = Set(keywordResults + semanticResults)
        return sortedIDs.compactMap { id in allCandidates.first { $0.id == id } }
    }

    // MARK: - Tag Aggregation
    func allTags(in pages: [WikiPage]) -> [(tag: String, count: Int)] {
        var tagCount: [String: Int] = [:]
        for page in pages {
            for tag in page.tags {
                tagCount[tag, default: 0] += 1
            }
        }
        return tagCount.map { ($0.key, $0.value) }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0 < $1.0
        }
    }
}

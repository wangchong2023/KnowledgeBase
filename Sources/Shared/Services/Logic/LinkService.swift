// LinkService.swift
//
// 作者: Wang Chong
// 功能说明: [L1] 领域层：处理链接解析、反向链接、搜索与标签聚合
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// [L1] 领域层：处理链接解析、反向链接、搜索与标签聚合
/// Actor 模式确保大规模并发下的线程安全。
actor LinkService {
    
    // MARK: - Link Resolution
    /**
     * @description: 根据标题或别名查找页面 (不区分大小写)
     * @param {String} title 目标标题
     * @param {[WikiPage]} pages 搜索范围
     * @return {WikiPage?} 匹配到的页面
     */
    func pageByTitle(_ title: String, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.title.lowercased() == title.lowercased() }
            ?? pages.first { $0.aliases.contains(where: { $0.lowercased() == title.lowercased() }) }
    }

    /**
     * @description: 获取引用了指定页面的所有反向链接页面
     * @param {UUID} pageID 目标页面 ID
     * @param {[WikiPage]} pages 搜索范围
     * @return {[WikiPage]} 引用者页面列表
     */
    func backlinks(for pageID: UUID, in pages: [WikiPage]) -> [WikiPage] {
        guard let page = pages.first(where: { $0.id == pageID }) else { return [] }
        return pages.filter { p in
            p.outgoingLinks.contains(where: { link in
                link.lowercased() == page.title.lowercased() ||
                page.aliases.contains(where: { $0.lowercased() == link.lowercased() })
            })
        }
    }

    /**
     * @description: 根据 ID 获取页面
     * @param {UUID} id 目标 ID
     * @param {[WikiPage]} pages 搜索范围
     * @return {WikiPage?} 匹配到的页面
     */
    func pageByID(_ id: UUID, in pages: [WikiPage]) -> WikiPage? {
        pages.first { $0.id == id }
    }

    // MARK: - Search
    func search(query: String, in pages: [WikiPage]) -> [WikiPage] {
        guard !query.isEmpty else { return pages }
        let q = query.lowercased()
        
        let filtered = pages.filter { page in
            page.title.lowercased().contains(q) ||
            page.content.lowercased().contains(q) ||
            page.tags.contains(where: { $0.lowercased().contains(q) }) ||
            page.aliases.contains(where: { $0.lowercased().contains(q) })
        }
        
        // 强制相关性排序：精确标题 > 包含标题 > 别名 > 正文
        return filtered.sorted { p1, p2 in
            let t1 = p1.title.lowercased()
            let t2 = p2.title.lowercased()
            
            // 1. 标题完全一致
            let exact1 = (t1 == q)
            let exact2 = (t2 == q)
            if exact1 != exact2 { return exact1 }
            
            // 2. 标题前缀匹配
            let prefix1 = t1.hasPrefix(q)
            let prefix2 = t2.hasPrefix(q)
            if prefix1 != prefix2 { return prefix1 }
            
            // 3. 标题包含
            let contains1 = t1.contains(q)
            let contains2 = t2.contains(q)
            if contains1 != contains2 { return contains1 }
            
            // 如果层级相同，保持原有稳定性
            return false
        }
    }
    
    /// 混合检索（带诊断信息版）
    func hybridSearchWithDiagnostics(query: String, in pages: [WikiPage], embeddingManager: EmbeddingManager) -> (results: [WikiPage], diagnostic: SearchDiagnosticInfo) {
        let keywordResults = search(query: query, in: pages)
        let semanticScored = embeddingManager.search(query: query)
        
        // 动态门槛：对于短查询，语义门槛要极高，否则噪音太大
        let similarityThreshold: Float = query.count < 4 ? 0.85 : 0.75
        
        let semanticResults = semanticScored
            .filter { res -> Bool in
                // 动态门槛：对于短查询，语义门槛要极高
                if query.count < 4 {
                    // 对于短词，如果语义得分不足 0.88，则必须包含关键词
                    if res.score > 0.88 { return true }
                    if let page = pages.first(where: { $0.id == res.id }) {
                        let lowerTitle = page.title.lowercased()
                        let lowerQuery = query.lowercased()
                        return lowerTitle.contains(lowerQuery)
                    }
                    return false
                }
                return res.score > similarityThreshold
            }
            .compactMap { res -> WikiPage? in
                pages.first { $0.id == res.id }
            }
        
        let k = 60
        var scores: [UUID: Double] = [:]
        var diagMap: [UUID: (fts: Int, vec: Int)] = [:]
        
        // 动态权重：对于短查询（如 "3D"），关键词匹配更可靠
        let keywordWeight = query.count < 4 ? 1.5 : 1.0
        let semanticWeight = 1.0
        
        for (index, page) in keywordResults.enumerated() {
            scores[page.id, default: 0] += (1.0 / Double(k + index + 1)) * keywordWeight
            diagMap[page.id] = (index + 1, -1)
        }
        
        for (index, page) in semanticResults.enumerated() {
            scores[page.id, default: 0] += (1.0 / Double(k + index + 1)) * semanticWeight
            let existing = diagMap[page.id] ?? (-1, -1)
            diagMap[page.id] = (existing.fts, index + 1)
        }
        
        let sortedIDs = scores.keys.sorted { scores[$0]! > scores[$1]! }
        let results = sortedIDs.compactMap { id in pages.first { $0.id == id } }
        
        let topDiagnostics = results.prefix(10).map { page in
            let ranks = diagMap[page.id]!
            return SearchDiagnosticInfo.ResultScore(
                id: page.id,
                title: page.title,
                ftsRank: ranks.fts,
                vectorRank: ranks.vec,
                finalScore: scores[page.id]!
            )
        }
        
        let diagnosticInfo = SearchDiagnosticInfo(
            query: query,
            rewrittenQuery: query, // 暂无重写逻辑
            ftsCount: keywordResults.count,
            vectorCount: semanticResults.count,
            rrfTopResults: topDiagnostics
        )
        
        return (results, diagnosticInfo)
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

    /**
     * @description: 提取全库所有标签及其引用计数，并按热度降序排列
     * @param {[WikiPage]} pages 页面全集
     * @return {[(tag: String, count: Int)]} 标签元组数组
     */
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
    
    // MARK: - Refactoring Logic
    
    /**
     * @description: 准备页面重命名流程，扫描库中所有对该页面的 [[]] 引用并执行替换
     * @param {WikiPage} page 待重命名的原始页面
     * @param {String} newTitle 新标题
     * @param {[WikiPage]} allPages 页面全集
     * @return {[WikiPage]} 返回所有受影响且已更新内容的页面列表
     */
    func prepareRename(page: WikiPage, to newTitle: String, in allPages: [WikiPage]) -> [WikiPage] {
        let oldTitle = page.title
        var modifiedPages: [WikiPage] = []
        
        // 1. 处理主页面
        var updatedMainPage = page
        updatedMainPage.title = newTitle
        updatedMainPage.updated = Date()
        modifiedPages.append(updatedMainPage)
        
        // 2. 扫描并替换其他页面中的反向链接
        for p in allPages where p.id != page.id {
            if p.content.contains("[[\(oldTitle)]]") {
                var refPage = p
                refPage.content = refPage.content.replacingOccurrences(of: "[[\(oldTitle)]]", with: "[[\(newTitle)]]")
                refPage.updated = Date()
                modifiedPages.append(refPage)
            }
        }
        
        return modifiedPages
    }
}

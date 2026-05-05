// IngestStore.swift
//
// 作者: Wang Chong
// 功能说明: 摄入业务存储，专门负责文件导入、智能提取及摄入工作流管理。
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation
import Combine

/// 摄入业务存储，专门负责文件导入、智能提取及摄入工作流管理。
/// 实现从“原始数据”到“系统页面”的转换逻辑。
@MainActor
@Observable
final class IngestStore {
    @ObservationIgnored @Inject private var sqliteStore: SQLiteStore
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject private var logger: any LoggerProtocol
    @ObservationIgnored @Inject private var ingestService: IngestService
    
    init() {}
    
    struct ExtractedURLContent { let title: String; let content: String }
    
    /// 从 URL 抓取内容
    func fetchURLContent(urlString: String) async throws -> ExtractedURLContent {
        let result = try await ingestService.scraper.fetchMarkdown(from: urlString)
        return ExtractedURLContent(title: result.title, content: result.markdown)
    }

    /// 确认并完成智能摄入
    func finalizeSmartIngest(title: String, result: SmartIngestResult, customIcon: String?) async -> WikiPage {
        let type: PageType = PageType(rawValue: result.suggestedType) ?? .concept
        
        // 我们需要一种方式来创建页面，而不依赖 KMStore
        // 这里我们直接模拟 createPage 逻辑，或者调用底层 Repository
        var page = WikiPage(title: title, content: result.compiledContent)
        page.type = type
        page.customIcon = customIcon
        page.tags = result.suggestedTags
        
        // 自动建立关联
        var relatedIDs: [UUID] = []
        for t in result.relatedTitles {
            if let linked = sqliteStore.pages.first(where: { $0.title == t }) {
                relatedIDs.append(linked.id)
            }
        }
        page.relatedPageIDs = relatedIDs
        
        // 持久化
        sqliteStore.syncRemotePage(page)
        
        logger.addLog(action: .smartIngest, target: title, details: Localized.trf("ingest.smartIngestDoneDesc", type.displayName))
        HapticFeedback.shared.trigger(.success)
        
        // 刷新缓存
        sqliteStore.reloadFromDisk()
        
        return page
    }
    
    /// 执行综合摄入逻辑
    @discardableResult
    func performIngest(
        title: String,
        content: String,
        type: PageType,
        tags: [String],
        customIcon: String?,
        useSmart: Bool,
        useDeepScan: Bool
    ) async throws -> WikiPage {
        let taskID = TaskCenter.shared.addTask(type: .ingest, name: Localized.tr("ingest.manualEntry"), target: title)
        
        do {
            let page: WikiPage
            if useSmart && llmService.isEnabled {
                let result = try await llmService.smartIngest(title: title, rawContent: content, pages: sqliteStore.pages)
                let pageType = PageType(rawValue: result.suggestedType) ?? type
                
                // 借用 finalizeSmartIngest 的逻辑进行创建
                page = await finalizeSmartIngest(title: title, result: result, customIcon: customIcon)
                logger.addLog(action: .smartIngest, target: title, details: Localized.trf("ingest.smartIngestDoneDesc", pageType.displayName))
            } else {
                // 使用 IngestService 的标准流程
                page = try await ingestWithFolding(
                    title: title,
                    content: content,
                    type: type,
                    forceDeepScan: useDeepScan
                )
                
                var updatedPage = page
                updatedPage.tags = tags
                updatedPage.customIcon = customIcon
                sqliteStore.updatePage(updatedPage, forceDeepScan: false)
            }
            
            TaskCenter.shared.updateTask(taskID, status: .completed, associatedPageID: page.id)
            HapticFeedback.shared.trigger(.success)
            sqliteStore.reloadFromDisk() // 确保数据同步
            return page
        } catch {
            TaskCenter.shared.updateTask(taskID, status: .failed(error: error.localizedDescription))
            throw error
        }
    }
    
    private func ingestWithFolding(title: String, content: String, type: PageType, forceDeepScan: Bool) async throws -> WikiPage {
        return ingestService.ingestRawContent(
            title: title,
            content: content,
            type: type,
            forceDeepScan: forceDeepScan,
            llmService: llmService,
            pageStore: sqliteStore
        )
    }
    
    /// 从外部文件直接导入（拖拽/文件选择器），异步处理
    func importFile(at url: URL) {
        logger.debug("📥 [IngestStore] 正在导入文件：\(url.lastPathComponent)")
        guard let content = try? String(contentsOf: url) else {
            logger.error("❌ [IngestStore] 无法读取文件内容：\(url.path)")
            return
        }

        IngestQueue.shared.enqueue(
            title: url.deletingPathExtension().lastPathComponent,
            content: content,
            llmService: llmService,
            pages: sqliteStore.pages
        ) { [weak self] page in
            guard let self = self else { return }
            var p = page
            p.id = UUID()
            self.sqliteStore.syncRemotePage(p)
        }
    }

    /// 处理文件导入流程（含提取与安全校验）
    func handleFileUpload(at url: URL) throws -> (title: String, content: String) {
        guard url.startAccessingSecurityScopedResource() else { 
            throw NSError(domain: "IngestStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // 文件大小限制 (50MB)
        if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
           let fileSize = resources.fileSize {
            let limit = 50 * 1024 * 1024
            if fileSize > limit {
                throw NSError(domain: "IngestStore", code: 2, userInfo: [NSLocalizedDescriptionKey: Localized.tr("ingest.fileTooLarge")])
            }
        }
        
        guard let extracted = ingestService.ingestDocument(at: url, pageStore: sqliteStore) else { 
            throw NSError(domain: "IngestStore", code: 3, userInfo: [NSLocalizedDescriptionKey: Localized.tr("ingest.error")])
        }
        
        return (extracted.title, extracted.content)
    }
}

import SwiftUI
import PDFKit

/// 数据导出与迁移服务 (Product Manager 视角：增强用户数据安全感与可迁移性)
final class DataExportService {
    nonisolated(unsafe) static let shared = DataExportService()
    
    private init() {}
    
    /// 将全库导出为 Markdown 文件系统
    func exportAllToMarkdown(pages: [WikiPage], destinationURL: URL) async throws {
        let syncService = FileSystemSyncService()
        try syncService.exportToMarkdown(pages: pages, destinationURL: destinationURL)
        
        // 记录操作日志
        LogService.shared.addLog(
            action: Localized.tr("action.export"),
            target: Localized.tr("export.allMarkdown"),
            details: Localized.trf("export.countFormat", pages.count)
        )
    }
    
    /// 生成 AI 驱动的 PDF 知识报告
    @MainActor
    func generatePDFReport(pages: [WikiPage]) async throws -> URL {
        let markdown = pages.map { "# \($0.title)\n\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        let fileName = "ZhiYuan_Knowledge_Report_\(Int(Date().timeIntervalSince1970))"
        
        let url = try await WebViewExportService.shared.exportToPDF(markdown: markdown, fileName: fileName)
        
        LogService.shared.addLog(
            action: Localized.tr("action.export"),
            target: "PDF Report",
            details: Localized.trf("export.countFormat", pages.count)
        )
        
        return url
    }
    
    /// 备份金库到 ZIP 压缩包
    func createVaultArchive(vaultURL: URL) async throws -> URL {
        // 实现 ZIP 压缩逻辑
        fatalError("Not implemented")
    }
}

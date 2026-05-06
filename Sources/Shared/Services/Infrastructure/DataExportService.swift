// DataExportService.swift
//
// 作者: Wang Chong
// 功能说明: 数据导出与迁移服务 (Product Manager 视角：增强用户数据安全感与可迁移性)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
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
        Logger.shared.addLog(
            action: .export,
            target: "export.allMarkdown",
            details: Localized.trf("export.countFormat", pages.count)
        )
    }
    
    /// 生成 AI 驱动的 PDF 知识报告
    @MainActor
    func generatePDFReport(pages: [WikiPage]) async throws -> URL {
        let markdown = pages.map { "# \($0.title)\n\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        let fileName = "ZhiYu_Knowledge_Report_\(Int(Date().timeIntervalSince1970))"
        
        let url = try await WebViewExportService.shared.exportToPDF(markdown: markdown, fileName: fileName)
        
        Logger.shared.addLog(
            action: .export,
            target: "PDF Report",
            details: Localized.trf("export.countFormat", pages.count)
        )
        
        return url
    }
    
    /// 备份金库到 ZIP 压缩包
    func createVaultArchive(vaultURL: URL) async throws -> URL {
        throw DataExportError.notImplemented
    }
}

enum DataExportError: LocalizedError {
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "ZIP archive creation is not yet implemented"
        }
    }
}

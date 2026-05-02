import SwiftUI
import PDFKit

/// 数据导出与迁移服务 (Product Manager 视角：增强用户数据安全感与可迁移性)
final class DataExportService {
    static let shared = DataExportService()
    
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
        let reportView = ExportReportView(pages: pages)
        let renderer = ImageRenderer(content: reportView)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZhiMind_Knowledge_Report_\(Int(Date().timeIntervalSince1970)).pdf")
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdfContext = CGContext(tempURL as CFURL, mediaBox: &box, nil) else {
                return
            }
            
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        
        LogService.shared.addLog(
            action: Localized.tr("action.export"),
            target: "PDF Report",
            details: Localized.trf("export.countFormat", pages.count)
        )
        
        return tempURL
    }
    
    /// 备份金库到 ZIP 压缩包
    func createVaultArchive(vaultURL: URL) async throws -> URL {
        // 实现 ZIP 压缩逻辑
        fatalError("Not implemented")
    }
}

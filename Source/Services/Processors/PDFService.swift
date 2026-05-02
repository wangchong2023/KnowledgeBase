import SwiftUI
import PDFKit

// MARK: - PDF Document Model

/// PDF 文档信息模型
///
/// 存储 PDF 文档的元数据，包括标题、页数、阅读进度、高亮内容和关联的知识库页面。
/// 用于在知识库中管理和追踪用户导入的 PDF 文档。
struct PDFDocumentInfo: Identifiable, Codable {
    let id: UUID
    var title: String
    var fileName: String
    var pageCount: Int
    var addedDate: Date
    var lastReadPage: Int
    var highlights: [PDFHighlight]
    var linkedPageTitles: [String]  // WikiPages linked from this PDF
    
    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        pageCount: Int,
        addedDate: Date = Date(),
        lastReadPage: Int = 0,
        highlights: [PDFHighlight] = [],
        linkedPageTitles: [String] = []
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.pageCount = pageCount
        self.addedDate = addedDate
        self.lastReadPage = lastReadPage
        self.highlights = highlights
        self.linkedPageTitles = linkedPageTitles
    }
}

// MARK: - PDF Highlight

/// PDF 高亮标记模型
///
/// 表示 PDF 页面中的一段高亮文本，支持多种颜色和笔记功能。
/// 高亮颜色支持：黄、绿、蓝、粉、紫五种颜色。
struct PDFHighlight: Identifiable, Codable {
    let id: UUID
    var pageIndex: Int
    var text: String
    var color: String  // "yellow", "green", "blue", "pink", "purple"
    var note: String
    var creationDate: Date
    
    init(
        id: UUID = UUID(),
        pageIndex: Int,
        text: String,
        color: String = "yellow",
        note: String = "",
        creationDate: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.text = text
        self.color = color
        self.note = note
        self.creationDate = creationDate
    }
    
    var highlightColor: Color {
        switch color {
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        case "purple": return .purple
        default: return .yellow
        }
    }
}

// MARK: - PDF Service

/// PDF 文档服务
///
/// 负责 PDF 文件的存储、加载、删除和文本提取。
/// 所有 PDF 文件存储在应用的 Documents/KMPDFs 目录下，
/// 元数据（标题、进度、高亮等）以 JSON 格式保存在同一目录下的 pdf_metadata.json 文件中。
///
/// ## 主要功能
/// - PDF 文件的保存、加载、删除
/// - 从 PDF 中提取文本内容（支持按页范围提取）
/// - 文档元数据的持久化
///
/// ## 使用方式
/// ```swift
/// let pdfService = PDFService.shared
/// if let document = pdfService.loadPDF(fileName: "document.pdf") {
///     let text = pdfService.extractText(from: document)
/// }
/// ```
class PDFService {
    static let shared = PDFService()
    
    private let documentsDirectory: URL
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KMPDFs", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Management

    /// 保存 PDF 数据到本地存储
    /// - Parameters:
    ///   - data: PDF 文件的二进制数据
    ///   - fileName: 保存的文件名（含扩展名）
    /// - Returns: 保存后的文件 URL，失败返回 nil
    func savePDF(data: Data, fileName: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    /// 从本地存储加载 PDF 文档
    /// - Parameter fileName: PDF 文件名
    /// - Returns: PDFKit.PDFDocument 对象，加载失败返回 nil
    func loadPDF(fileName: String) -> PDFKit.PDFDocument? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return PDFKit.PDFDocument(url: fileURL)
    }
    
    /// 从本地存储删除 PDF 文件
    /// - Parameter fileName: 要删除的 PDF 文件名
    /// - Returns: 删除成功返回 true，失败返回 false
    func deletePDF(fileName: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    /// 获取本地存储的所有 PDF 文件名列表
    /// - Returns: 按文件名升序排列的 PDF 文件名数组
    func allPDFFilenames() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return files
                .filter { $0.pathExtension == "pdf" }
                .map { $0.lastPathComponent }
                .sorted()
        } catch {
            return []
        }
    }
    
    // MARK: - Text Extraction

    /// 从 PDF 文档中提取文本内容
    /// - Parameters:
    ///   - pdfDocument: PDFKit 文档对象
    ///   - pageRange: 可选的页码范围，nil 表示提取所有页面
    /// - Returns: 提取的文本内容，页面之间以换行符分隔
    func extractText(from pdfDocument: PDFKit.PDFDocument, pageRange: Range<Int>? = nil) -> String {
        var text = ""
        let start = pageRange?.lowerBound ?? 0
        let end = pageRange?.upperBound ?? pdfDocument.pageCount

        for i in start..<min(end, pdfDocument.pageCount) {
            if let page = pdfDocument.page(at: i) {
                text += page.string ?? ""
                text += String(format: Localized.tr("pdf.pageSeparator"), i + 1)
            }
        }
        return text
    }

    /// 从 URL 提取 PDF 文本内容
    /// - Parameter url: PDF 文件的 URL
    /// - Returns: 提取的文本内容，提取失败返回 nil
    static func extractText(from url: URL) -> String? {
        guard let document = PDFKit.PDFDocument(url: url) else { return nil }
        var text = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                text += page.string ?? ""
                text += String(format: Localized.tr("pdf.pageSeparator"), i + 1)
            }
        }
        return text
    }

    /// 从 URL 提取 PDF 文本内容（实例方法版本）
    func extractText(from url: URL) -> String? {
        guard let document = PDFKit.PDFDocument(url: url) else { return nil }
        return extractText(from: document)
    }

    // MARK: - Metadata Persistence

    /// 保存文档元数据到本地存储
    /// - Parameter docs: PDFDocumentInfo 数组，会覆盖原有元数据
    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: url)
        }
    }
    
    /// 从本地存储加载文档元数据
    /// - Returns: PDFDocumentInfo 数组，无数据时返回空数组
    func loadDocumentsInfo() -> [PDFDocumentInfo] {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        guard let data = try? Data(contentsOf: url),
              let docs = try? JSONDecoder().decode([PDFDocumentInfo].self, from: data) else {
            return []
        }
        return docs
    }
}

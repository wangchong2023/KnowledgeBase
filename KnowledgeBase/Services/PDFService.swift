import SwiftUI
import PDFKit

// MARK: - PDF Document Model
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
    func savePDF(data: Data, fileName: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func loadPDF(fileName: String) -> PDFKit.PDFDocument? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return PDFKit.PDFDocument(url: fileURL)
    }
    
    func deletePDF(fileName: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
    
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
    func extractText(from pdfDocument: PDFKit.PDFDocument, pageRange: Range<Int>? = nil) -> String {
        var text = ""
        let start = pageRange?.lowerBound ?? 0
        let end = pageRange?.upperBound ?? pdfDocument.pageCount
        
        for i in start..<min(end, pdfDocument.pageCount) {
            if let page = pdfDocument.page(at: i) {
                text += page.string ?? ""
                text += String(format: L.tr("pdf.pageSeparator"), i + 1)
            }
        }
        return text
    }
    
    // MARK: - Metadata Persistence
    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: url)
        }
    }
    
    func loadDocumentsInfo() -> [PDFDocumentInfo] {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        guard let data = try? Data(contentsOf: url),
              let docs = try? JSONDecoder().decode([PDFDocumentInfo].self, from: data) else {
            return []
        }
        return docs
    }
}

import SwiftUI
import PDFKit

// MARK: - PDF Ingest Sheet
struct PDFIngestSheet: View {
    let documentInfo: PDFDocumentInfo
    @ObservedObject var store: KMStore
    let pdfDocument: PDFKit.PDFDocument?
    
    @State private var ingestMode = "fullText"
    @State private var pageStart = 1
    @State private var pageEnd = 1
    @State private var targetType = PageType.source
    @State private var targetTitle = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                targetSection
                rangeSection
                highlightsSection
                previewSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.wikiBackground)
            .navigationTitle("导入到知识库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") { ingestContent() }
                        .fontWeight(.semibold)
                        .disabled(targetTitle.isEmpty)
                }
            }
            .onAppear {
                targetTitle = documentInfo.title
                pageEnd = documentInfo.pageCount
            }
        }
    }
    
    // MARK: - Target Section
    private var targetSection: some View {
        Section {
            TextField("页面标题", text: $targetTitle)
                .foregroundStyle(.wikiText)
            
            Picker("页面类型", selection: $targetType) {
                ForEach(PageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text("目标页面")
        }
    }
    
    // MARK: - Range Section
    private var rangeSection: some View {
        Section {
            Picker("提取方式", selection: $ingestMode) {
                Text("全文").tag("fullText")
                Text("指定页范围").tag("pageRange")
                Text("仅标注内容").tag("highlights")
            }
            .pickerStyle(.segmented)
            
            if ingestMode == "pageRange" {
                HStack {
                    Text("从第")
                    TextField("1", value: $pageStart, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                    Text("页到第")
                    TextField("\(documentInfo.pageCount)", value: $pageEnd, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                    Text("页")
                }
                .foregroundStyle(.wikiText)
            }
        } header: {
            Text("提取范围")
        }
    }
    
    // MARK: - Highlights Section
    @ViewBuilder
    private var highlightsSection: some View {
        if ingestMode == "highlights" && documentInfo.highlights.isEmpty {
            Section {
                Text("暂无标注内容，请先在阅读时添加高亮标注")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        Section {
            ScrollView {
                Text(previewText)
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                    .lineLimit(10)
            }
            .frame(maxHeight: 150)
        } header: {
            Text("内容预览")
        }
    }
    
    // MARK: - Preview Text
    private var previewText: String {
        switch ingestMode {
        case "fullText":
            guard let pdfDoc = pdfDocument else { return "无法加载 PDF" }
            let text = PDFService.shared.extractText(from: pdfDoc, pageRange: 0..<min(2, pdfDoc.pageCount))
            return String(text.prefix(500))
        case "pageRange":
            guard let pdfDoc = pdfDocument else { return "" }
            let start = max(0, pageStart - 1)
            let end = min(pdfDoc.pageCount, pageEnd)
            let text = PDFService.shared.extractText(from: pdfDoc, pageRange: start..<end)
            return String(text.prefix(500))
        case "highlights":
            let texts = documentInfo.highlights.map { $0.text }
            return texts.joined(separator: "\n\n").prefix(500).description
        default:
            return ""
        }
    }
    
    // MARK: - Ingest Content
    private func ingestContent() {
        var content = ""
        
        switch ingestMode {
        case "fullText":
            if let pdfDoc = pdfDocument {
                content = PDFService.shared.extractText(from: pdfDoc)
            }
        case "pageRange":
            if let pdfDoc = pdfDocument {
                let start = max(0, pageStart - 1)
                let end = min(pdfDoc.pageCount, pageEnd)
                content = PDFService.shared.extractText(from: pdfDoc, pageRange: start..<end)
            }
        case "highlights":
            content = documentInfo.highlights.map { h in
                var text = "> \(h.text)"
                if !h.note.isEmpty {
                    text += "\n\n备注：\(h.note)"
                }
                return text
            }.joined(separator: "\n\n---\n\n")
        default:
            break
        }
        
        let _ = store.createPage(
            title: targetTitle,
            type: targetType,
            content: content,
            tags: ["PDF", "导入"]
        )
        store.addLog(action: "导入PDF", target: targetTitle, details: "模式: \(ingestMode)")
        store.saveToDisk()
        dismiss()
    }
}

// MARK: - PDF Document Row
struct PDFDocumentRow: View {
    let doc: PDFDocumentInfo
    
    var body: some View {
        HStack(spacing: 12) {
            pdfIcon
            docInfo
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
        }
        .padding(.vertical, 4)
    }
    
    private var pdfIcon: some View {
        RoundedRectangle(cornerRadius: WikiUI.microRadius)
            .fill(Color.wikiAccent.opacity(0.15))
            .frame(width: 48, height: 64)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.title3)
                        .foregroundStyle(.wikiAccent)
                    Text("\(doc.pageCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.wikiAccent)
                }
            )
    }
    
    private var docInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(doc.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.wikiText)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                Label("\(doc.pageCount) 页", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                
                Label("\(doc.highlights.count) 标注", systemImage: "highlighter")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Text(doc.addedDate.formatted(.dateTime.month().day()))
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        }
    }
}

// MARK: - Highlight Color Extension
extension Color {
    static func pdfHighlight(_ name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        case "purple": return .purple
        default: return .yellow
        }
    }
}
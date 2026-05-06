// PDFComponents.swift
//
// 作者: Wang Chong
// 功能说明: struct PDFIngestSheet
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-04
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import SwiftUI
import PDFKit

// MARK: - PDF Ingest Sheet
/// PDF 资料入库配置面板组件
/// 负责配置 PDF 内容的提取方式（全文、范围或仅高亮），并设定目标 Wiki 页面的元数据
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
            .navigationTitle(Localized.tr("pdf.ingestToWiki"))
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(Localized.tr("pdf.ingest")) { ingestContent() }
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
            TextField(Localized.tr("pdf.pageTitle"), text: $targetTitle)
                .foregroundStyle(.wikiText)
            
            Picker(Localized.tr("pdf.pageType"), selection: $targetType) {
                ForEach(PageType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text(Localized.tr("pdf.targetPage"))
        }
    }
    
    // MARK: - Range Section
    private var rangeSection: some View {
        Section {
            Picker(Localized.tr("pdf.extractionMethod"), selection: $ingestMode) {
                Text(Localized.tr("pdf.fullText")).tag("fullText")
                Text(Localized.tr("pdf.pageRange")).tag("pageRange")
                Text(Localized.tr("pdf.highlightsOnly")).tag("highlights")
            }
            .pickerStyle(.segmented)
            
            if ingestMode == "pageRange" {
                HStack {
                    Text(Localized.tr("pdf.fromPage"))
                    TextField("1", value: $pageStart, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                    Text(Localized.tr("pdf.toPage"))
                    TextField("\(documentInfo.pageCount)", value: $pageEnd, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                    Text(Localized.tr("pdf.page"))
                }
                .foregroundStyle(.wikiText)
            }
        } header: {
            Text(Localized.tr("pdf.extractionRange"))
        }
    }
    
    // MARK: - Highlights Section
    @ViewBuilder
    private var highlightsSection: some View {
        if ingestMode == "highlights" && documentInfo.highlights.isEmpty {
            Section {
                Text(Localized.tr("pdf.noHighlights"))
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
            Text(Localized.tr("pdf.contentPreview"))
        }
    }
    
    // MARK: - Preview Text
    private var previewText: String {
        switch ingestMode {
        case "fullText":
            guard let pdfDoc = pdfDocument else { return Localized.tr("pdf.cannotLoadPDF") }
            let text = store.extractPDFText(from: pdfDoc, pageRange: 0..<min(2, pdfDoc.pageCount))
            return String(text.prefix(500))
        case "pageRange":
            guard let pdfDoc = pdfDocument else { return "" }
            let start = max(0, pageStart - 1)
            let end = min(pdfDoc.pageCount, pageEnd)
            let text = store.extractPDFText(from: pdfDoc, pageRange: start..<end)
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
                content = store.extractPDFText(from: pdfDoc)
            }
        case "pageRange":
            if let pdfDoc = pdfDocument {
                let start = max(0, pageStart - 1)
                let end = min(pdfDoc.pageCount, pageEnd)
                content = store.extractPDFText(from: pdfDoc, pageRange: start..<end)
            }
        case "highlights":
            content = documentInfo.highlights.map { h in
                var text = "> \(h.text)"
                if !h.note.isEmpty {
                    text += "\n\n\(Localized.tr("pdf.noteLabel")) \(h.note)"
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
            tags: ["PDF", Localized.tr("logAction.ingest")]
        )
        store.addLog(action: .importPDF, target: targetTitle, details: Localized.trf("pdf.ingestModeFormat", ingestMode))
        store.saveToDisk()
        dismiss()
    }
}

// MARK: - PDF Document Row
/// PDF 文档列表行组件
/// 负责展示 PDF 文件的基本元数据（标题、页数、高亮统计）及预览图标
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
                Label(Localized.trf("pdf.pageCountFormat", doc.pageCount), systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
                
                Label(Localized.trf("pdf.highlightCountFormat", doc.highlights.count), systemImage: "highlighter")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)
            }
            
            Text(doc.addedDate.formatted(.dateTime.month().day()))
                .font(.caption2)
                .foregroundStyle(.wikiSecondary)
        }
    }
}

// MARK: - PDF Preview Wrapper
/// PDF 预览包装器组件
/// 负责在 SwiftUI 中嵌入原生 PDFView 渲染引擎，支持文档加载与自动缩放
struct PDFPreviewWrapper: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFKit.PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFKit.PDFDocument(url: url)
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
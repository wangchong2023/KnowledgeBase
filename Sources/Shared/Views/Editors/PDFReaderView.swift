import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - PDF Library View
@MainActor
struct PDFLibraryView: View {
    @EnvironmentObject var store: KMStore
    @State private var documents: [PDFDocumentInfo] = []
    @State private var showFilePicker = false
    @State private var selectedDoc: PDFDocumentInfo?

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    PDFLibraryEmptyView(onAdd: { showFilePicker = true })
                } else {
                    PDFDocumentListView(
                        documents: documents,
                        onSelect: { selectedDoc = $0 },
                        onDelete: deleteDocument,
                        onIngest: ingestPDF
                    )
                }
            }
            .navigationTitle(Localized.tr("pdf.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(item: $selectedDoc) { doc in
                PDFReaderView(documentInfo: doc, store: store)
            }
            .onAppear {
                documents = PDFService.shared.loadDocumentsInfo()
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            guard let data = try? Data(contentsOf: url) else { return }
            let fileName = "\(UUID().uuidString).pdf"

            if PDFService.shared.savePDF(data: data, fileName: fileName) != nil {
                let pdfDoc = PDFKit.PDFDocument(data: data)
                let docInfo = PDFDocumentInfo(
                    title: url.deletingPathExtension().lastPathComponent,
                    fileName: fileName,
                    pageCount: pdfDoc?.pageCount ?? 0
                )
                documents.append(docInfo)
                PDFService.shared.saveDocumentsInfo(documents)
                store.addLog(action: Localized.tr("logAction.importPDF"), target: docInfo.title, details: Localized.trf("pdf.pageCountFormat", docInfo.pageCount))
            }

        case .failure(let error):
            store.addLog(action: Localized.tr("logAction.importPDFFailed"), target: "", details: error.localizedDescription)
        }
    }

    private func deleteDocument(_ doc: PDFDocumentInfo) {
        _ = PDFService.shared.deletePDF(fileName: doc.fileName)
        documents.removeAll { $0.id == doc.id }
        PDFService.shared.saveDocumentsInfo(documents)
        store.addLog(action: Localized.tr("logAction.deletePDF"), target: doc.title)
    }

    private func ingestPDF(_ doc: PDFDocumentInfo) {
        guard let pdfDoc = PDFService.shared.loadPDF(fileName: doc.fileName) else { return }
        let text = PDFService.shared.extractText(from: pdfDoc)

        if !text.isEmpty {
            let page = store.createPage(
                title: doc.title,
                type: .source,
                content: text,
                tags: ["PDF", Localized.tr("logAction.ingest")]
            )
            store.addLog(action: Localized.tr("logAction.importPDF"), target: doc.title, details: Localized.trf("pdf.createdPage", page.title))
            store.saveToDisk()
        }
    }
}

// MARK: - PDF Library Empty View
private struct PDFLibraryEmptyView: View {
    let onAdd: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(Localized.tr("pdf.library"), systemImage: "doc.richtext")
        } description: {
            Text(Localized.tr("pdf.libraryHint"))
        } actions: {
            Button(Localized.tr("pdf.add")) { onAdd() }
                .buttonStyle(.borderedProminent)
                .tint(.wikiAccent)
        }
    }
}

// MARK: - PDF Document List View
private struct PDFDocumentListView: View {
    let documents: [PDFDocumentInfo]
    let onSelect: (PDFDocumentInfo) -> Void
    let onDelete: (PDFDocumentInfo) -> Void
    let onIngest: (PDFDocumentInfo) -> Void

    var body: some View {
        List {
            ForEach(documents) { doc in
                Button(action: { onSelect(doc) }) {
                    PDFDocumentRow(doc: doc)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete(doc)
                    } label: {
                        Label(Localized.tr("pdf.delete"), systemImage: "trash")
                    }

                    Button(action: { onIngest(doc) }) {
                        Label(Localized.tr("pdf.ingest"), systemImage: "arrow.down.doc")
                    }
                    .tint(.wikiAccent)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.wikiBackground)
    }
}

// MARK: - PDF Reader View (Full Screen)
struct PDFReaderView: View {
    let documentInfo: PDFDocumentInfo
    @ObservedObject var store: KMStore

    @State private var currentPage = 0
    @State private var highlights: [PDFHighlight] = []
    @State private var showHighlightPanel = false
    @State private var showIngestSheet = false
    @State private var selectedText = ""
    @State private var highlightColor = "yellow"
    @State private var highlightNote = ""
    @State private var pdfDocument: PDFKit.PDFDocument?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wikiBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    pdfContent
                    bottomBar
                }
            }
            .navigationTitle(documentInfo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showHighlightPanel.toggle() }) {
                        Image(systemName: showHighlightPanel ? "highlighter.fill" : "highlighter")
                    }

                    Button(action: { showIngestSheet = true }) {
                        Image(systemName: "arrow.down.doc")
                    }
                }
            }
            .sheet(isPresented: $showIngestSheet) {
                PDFIngestSheet(documentInfo: documentInfo, store: store, pdfDocument: pdfDocument)
            }
        }
        .onAppear {
            pdfDocument = PDFService.shared.loadPDF(fileName: documentInfo.fileName)
            highlights = documentInfo.highlights
            currentPage = documentInfo.lastReadPage
        }
    }

    // MARK: - PDF Content
    @ViewBuilder
    private var pdfContent: some View {
        if let pdfDoc = pdfDocument {
            PDFKitRepresentedView(
                document: pdfDoc,
                currentPage: $currentPage,
                onTextSelected: { selectedText = $0 }
            )
            .ignoresSafeArea()
        } else {
            ContentUnavailableView(Localized.tr("pdf.cannotLoadPDF"), systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if showHighlightPanel && !selectedText.isEmpty {
                highlightEditor
            }

            HStack {
                Text("\(currentPage + 1) / \(pdfDocument?.pageCount ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.wikiSecondary)

                Spacer()

                if !highlights.isEmpty {
                    Button(action: { showHighlightPanel.toggle() }) {
                        Label("\(highlights.count)", systemImage: "highlighter")
                            .font(.caption)
                            .foregroundStyle(.wikiAccent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.wikiCard)
        }
    }

    // MARK: - Highlight Editor
    private var highlightEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Localized.tr("pdf.annotateSelected"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.wikiText)

            Text(selectedText)
                .font(.caption)
                .foregroundStyle(.wikiSecondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                ForEach(["yellow", "green", "blue", "pink", "purple"], id: \.self) { color in
                    Button(action: { highlightColor = color }) {
                        Circle()
                            .fill(Color.pdfHighlight(color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.wikiText, lineWidth: highlightColor == color ? 2 : 0)
                            )
                    }
                }
                Spacer()
            }

            TextField(Localized.tr("pdf.addNote"), text: $highlightNote)
                .font(.caption)
                .textFieldStyle(.roundedBorder)

            Button(action: saveHighlight) {
                Text(Localized.tr("pdf.saveAnnotation"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.wikiAccent, in: RoundedRectangle(cornerRadius: WikiUI.microRadius))
            }
        }
        .padding(12)
        .background(Color.wikiCard)
    }

    // MARK: - Actions
    private func saveHighlight() {
        let highlight = PDFHighlight(
            pageIndex: currentPage,
            text: selectedText,
            color: highlightColor,
            note: highlightNote
        )
        highlights.append(highlight)

        var docs = PDFService.shared.loadDocumentsInfo()
        if let index = docs.firstIndex(where: { $0.id == documentInfo.id }) {
            docs[index].highlights = highlights
            PDFService.shared.saveDocumentsInfo(docs)
        }

        selectedText = ""
        highlightNote = ""
        showHighlightPanel = false

        store.addLog(action: Localized.tr("logAction.highlight"), target: documentInfo.title, details: Localized.trf("pdf.pageNumber", currentPage + 1))
    }
}

// MARK: - PDFKit Represented View
struct PDFKitRepresentedView: UIViewRepresentable {
    let document: PDFKit.PDFDocument
    @Binding var currentPage: Int
    var onTextSelected: (String) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(Color.wikiBackground)

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitRepresentedView

        init(_ parent: PDFKitRepresentedView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: page)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}

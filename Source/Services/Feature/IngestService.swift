import Foundation
import Compression

// MARK: - Document Format

enum DocumentFormat {
    case markdown
    case plainText
    case docx
    case xlsx
    case pdf
    case unknown

    static func detectFormat(from url: URL) -> DocumentFormat {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "md", "markdown":
            return .markdown
        case "txt", "text":
            return .plainText
        case "docx":
            return .docx
        case "xlsx":
            return .xlsx
        case "pdf":
            return .pdf
        default:
            return .unknown
        }
    }
}

// MARK: - Page Store Protocol

/// Abstraction layer allowing different store implementations to serve as data sources.
/// SQLiteStore is the sole implementation; PageStore was removed (JSON-based, unused).
protocol AnyPageStore {
    var pages: [WikiPage] { get }
    @discardableResult
    func createPage(title: String, type: PageType, content: String, tags: [String], sourceURL: String?, rawSnippet: String?, forceDeepScan: Bool) -> WikiPage
    func updatePage(_ page: WikiPage, forceDeepScan: Bool)
}
// Note: SQLiteStore conformance is declared in SQLiteStore.swift to avoid circular dependency

// MARK: - Ingest Service (Knowledge Ingestion)

/// Handles raw content ingestion: creates source pages and auto-links existing concepts.
final class IngestService {
    let scraper = LinkScraperService()

    /// 将原始内容摄入知识库：创建新页面并自动链接已知概念。
    /// - Returns: The created page (with auto-linked content).
    func ingestRawContent(
        title: String,
        content: String,
        type: PageType = .source,
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        forceDeepScan: Bool = false,
        llmService: (any LLMServiceProtocol)? = nil,
        pageStore: any AnyPageStore
    ) -> WikiPage {
        // --- 语义增强流程 (处理图表) ---
        // TODO: 异步 LLM 语义增强（当前 defer，后续接入）
        // if let llm = llmService, content.contains("| --- |") || content.contains("![]") { }
        // Create raw source page with provenance
        let rawPage = pageStore.createPage(
            title: title,
            type: type,
            content: content,
            tags: ["ingested"],
            sourceURL: sourceURL,
            rawSnippet: rawSnippet ?? String(content.prefix(500)),
            forceDeepScan: forceDeepScan
        )

        // Auto-extract potential concept links from content
        let concepts = extractConcepts(from: content, pages: pageStore.pages)
        var updatedContent = rawPage.content

        for concept in concepts {
            updatedContent = updatedContent.replacingOccurrences(
                of: concept,
                with: "[[\(concept)]]"
            )
        }

        var page = rawPage
        page.content = updatedContent
        pageStore.updatePage(page, forceDeepScan: forceDeepScan)

        return page
    }

    /// 从 URL 摄入内容
    func ingestURL(
        urlString: String,
        forceDeepScan: Bool = true,
        llmService: (any LLMServiceProtocol)? = nil,
        pageStore: any AnyPageStore
    ) async throws -> WikiPage {
        let result = try await scraper.fetchMarkdown(from: urlString)
        var content = result.markdown
        
        // 语义增强
        if let llm = llmService {
            content = await enrichRichContent(content, llm: llm)
        }
        
        return ingestRawContent(
            title: result.title,
            content: content,
            type: .source,
            sourceURL: urlString,
            rawSnippet: String(content.prefix(1000)),
            forceDeepScan: forceDeepScan,
            llmService: llmService,
            pageStore: pageStore
        )
    }

    /// Extract existing page titles mentioned in the given content.
    func extractConcepts(from content: String, pages: [WikiPage]) -> [String] {
        var found: [String] = []
        for page in pages {
            if content.lowercased().contains(page.title.lowercased()) {
                found.append(page.title)
            }
        }
        return found
    }
    
    // MARK: - Semantic Enrichment
    
    /// 对 Markdown 中的图表进行语义增强，提升 RAG 召回率
    func enrichRichContent(_ content: String, llm: any LLMServiceProtocol) async -> String {
        let prompt = String(format: Localized.tr("ingest.enrichRichContentPrompt"), content)
        
        do {
            return try await llm.generate(prompt: prompt, temperature: 0.3)
        } catch {
            print("[Ingest] Enrichment failed: \(error)")
            return content
        }
    }

    // MARK: - Document Ingestion

    /// Ingest a document file, automatically detecting format and extracting text content.
    /// - Returns: The created WikiPage, or nil if extraction failed.
    func ingestDocument(
        at url: URL,
        title: String? = nil,
        type: PageType = .source,
        pageStore: any AnyPageStore
    ) -> WikiPage? {
        let format = DocumentFormat.detectFormat(from: url)

        let extractedTitle = title ?? url.deletingPathExtension().lastPathComponent
        var content: String?

        switch format {
        case .docx:
            content = extractTextFromDocx(at: url)
        case .xlsx:
            content = extractTextFromXlsx(at: url)
        case .markdown, .plainText:
            content = try? String(contentsOf: url, encoding: .utf8)
        case .pdf:
            content = PDFService.extractText(from: url)
        case .unknown:
            print("Unknown document format: \(url.pathExtension)")
            return nil
        }

        guard let text = content, !text.isEmpty else {
            print("Failed to extract text from document: \(url.path)")
            return nil
        }

        return ingestRawContent(title: extractedTitle, content: text, type: type, forceDeepScan: true, pageStore: pageStore)
    }

    /// Batch import all supported documents from a folder. (Enhanced: Eco-Indexing)
    func ingestFolder(
        at url: URL,
        type: PageType = .source,
        pageStore: any AnyPageStore
    ) -> [WikiPage] {
        var pages: [WikiPage] = []

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            print("Failed to enumerate folder: \(url.path)")
            return pages
        }
        
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        if isLowPowerMode {
            print(Localized.tr("ingest.ecoIndexingLowPower"))
        }

        for case let fileURL as URL in enumerator {
            // 智适应节流：低功耗模式下每个文件处理后强制休息，释放 CPU
            if isLowPowerMode {
                Thread.sleep(forTimeInterval: 0.2)
            }
            
            if let page = ingestDocument(at: fileURL, type: type, pageStore: pageStore) {
                pages.append(page)
                LocalAnalyticsService.shared.trackEvent("document_ingested", properties: ["format": fileURL.pathExtension])
            }
        }

        return pages
    }

    // MARK: - DOCX Text Extraction

    /// Extract text content from a DOCX file.
    /// DOCX is a ZIP archive containing document.xml with XML-formatted text.
    func extractTextFromDocx(at url: URL) -> String? {
        guard let archive = readZipArchive(at: url) else { return nil }

        guard let documentXML = archive["word/document.xml"] else {
            print("DOCX missing word/document.xml")
            return nil
        }

        let parser = DocxTextParser(xmlData: documentXML)
        if parser.parse() {
            return parser.extractedText
        } else {
            print("DOCX XML parsing failed")
            return nil
        }
    }

    // MARK: - XLSX Text Extraction

    /// Extract text content from an XLSX file.
    /// XLSX is a ZIP archive containing xl/sharedStrings.xml and sheet files.
    func extractTextFromXlsx(at url: URL) -> String? {
        guard let archive = readZipArchive(at: url) else { return nil }

        var sharedStrings: [String] = []

        // Extract shared strings (common string values)
        if let sharedStringsXML = archive["xl/sharedStrings.xml"] {
            let parser = XlsxSharedStringsParser(xmlData: sharedStringsXML)
            if parser.parse() {
                sharedStrings = parser.strings
            }
        }

        var allText: [String] = []

        // Extract from each sheet
        for (path, data) in archive {
            if path.hasPrefix("xl/worksheets/sheet") && path.hasSuffix(".xml") {
                let parser = XlsxSheetParser(xmlData: data)
                if parser.parse() {
                    // Resolve shared string references
                    for value in parser.values {
                        if value.hasPrefix("[") && value.hasSuffix("]"),
                           let index = Int(value.dropFirst().dropLast()),
                           index < sharedStrings.count {
                            allText.append(sharedStrings[index])
                        } else if !value.isEmpty && !value.hasPrefix("[") {
                            allText.append(value)
                        }
                    }
                }
            }
        }

        return allText.isEmpty ? nil : allText.joined(separator: "\n")
    }

    // MARK: - ZIP Archive Helper

    /// Read a ZIP archive and return a dictionary of file paths to their uncompressed data.
    private func readZipArchive(at url: URL) -> [String: Data]? {
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read file data: \(url.path)")
            return nil
        }

        var archive: [String: Data] = [:]

        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else { return }

            var offset = 0
            let count = buffer.count

            while offset + 30 < count {
                let bytes = baseAddress.advanced(by: offset)

                // Local file header signature
                guard bytes.load(as: UInt32.self) == 0x04034b50 else {
                    // Try to find next file header
                    if let nextOffset = findNextLocalFileHeader(in: buffer, start: offset) {
                        offset = nextOffset
                        continue
                    }
                    break
                }

                let fileNameLength = Int(bytes.load(fromByteOffset: 28, as: UInt16.self))
                let extraFieldLength = Int(bytes.load(fromByteOffset: 30, as: UInt16.self))
                let compressedSize = Int(bytes.load(fromByteOffset: 18, as: UInt32.self))

                let headerSize = 30 + fileNameLength + extraFieldLength
                let dataOffset = offset + headerSize

                guard dataOffset + compressedSize <= count else { break }

                let nameBytes = UnsafeRawPointer(baseAddress).advanced(by: offset + 30)
                let fileNameData = Data(bytes: nameBytes, count: fileNameLength)
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    offset += 4
                    continue
                }

                // Decompress if needed (method 0 = stored, 8 = deflate)
                let compressionMethod = UInt16(bytes.load(fromByteOffset: 8, as: UInt16.self))
                let compressedData = Data(bytes: baseAddress.advanced(by: dataOffset), count: compressedSize)

                if compressionMethod == 0 {
                    archive[fileName] = compressedData
                } else if compressionMethod == 8 {
                    if let decompressed = decompressDeflate(data: compressedData) {
                        archive[fileName] = decompressed
                    }
                }

                offset = dataOffset + compressedSize
            }
        }

        return archive.isEmpty ? nil : archive
    }

    private func findNextLocalFileHeader(in buffer: UnsafeRawBufferPointer, start: Int) -> Int? {
        let count = buffer.count
        var i = start + 4
        while i + 4 <= count {
            let sig = buffer.load(fromByteOffset: i, as: UInt32.self)
            if sig == 0x04034b50 {
                return i
            }
            i += 1
        }
        return nil
    }

    private func decompressDeflate(data: Data) -> Data? {
        let destinationBufferSize = data.count * 10
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)

        let result = data.withUnsafeBytes { (sourceBuffer: UnsafeRawBufferPointer) -> Int? in
            guard let sourcePointer = sourceBuffer.baseAddress else { return nil }

            return sourcePointer.withMemoryRebound(to: UInt8.self, capacity: data.count) { sourcePtr in
                compression_decode_buffer(
                    &destinationBuffer,
                    destinationBufferSize,
                    sourcePtr,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard let size = result, size > 0 else { return nil }
        return Data(destinationBuffer.prefix(size))
    }
}

// MARK: - DOCX XML Parser

private final class DocxTextParser: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var extractedText: String = ""
    private var inTextElement = false
    private var currentText = ""
    private var lastWasText = false

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "w:t" {
            inTextElement = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "w:t" {
            if !currentText.isEmpty {
                if lastWasText {
                    extractedText += " "
                }
                extractedText += currentText
                lastWasText = true
            }
            inTextElement = false
            currentText = ""
        } else if elementName == "w:p" {
            if lastWasText {
                extractedText += "\n"
                lastWasText = false
            }
        }
    }
}

// MARK: - XLSX Shared Strings Parser

private final class XlsxSharedStringsParser: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var strings: [String] = []
    private var inTextElement = false
    private var currentText = ""

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "t" {
            inTextElement = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            strings.append(currentText)
            inTextElement = false
            currentText = ""
        }
    }
}

// MARK: - XLSX Sheet Parser

private final class XlsxSheetParser: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var values: [String] = []
    private var inCellElement = false
    private var inValueElement = false
    private var currentText = ""
    private var currentCellType: String?

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "c" {
            currentCellType = attributeDict["t"]
            inCellElement = true
            currentText = ""
        } else if elementName == "v" {
            inValueElement = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValueElement {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            inValueElement = false
        } else if elementName == "c" {
            if !currentText.isEmpty && (currentCellType == "s" || currentCellType == "inlineStr") {
                if let value = Int(currentText), value < 10000 {
                    values.append("[\(value)]")
                }
            }
            inCellElement = false
            currentCellType = nil
            currentText = ""
        }
    }
}
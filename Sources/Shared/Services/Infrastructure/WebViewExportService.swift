import SwiftUI
import WebKit

/// 网页导出服务 (L0 基础架构层)
/// 利用不可见的 WKWebView 执行 JavaScript (PptxGenJS / Marked.js) 实现跨平台导出。
@MainActor
final class WebViewExportService: NSObject {
    static let shared = WebViewExportService()
    
    private var webView: WKWebView?
    private var exportContinuation: CheckedContinuation<URL, Error>?
    
    private override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        
        // 读取本地 JS 内容
        let pptxJS = loadLocalJS(named: "pptxgen.bundle")
        let markedJS = loadLocalJS(named: "marked.min")
        let mermaidJS = loadLocalJS(named: "mermaid.min")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script>\(pptxJS)</script>
            <script>\(markedJS)</script>
            <script>\(mermaidJS)</script>
            <style>
                body { font-family: -apple-system, sans-serif; padding: 40px; color: #333; line-height: 1.6; }
                h1 { color: #222; border-bottom: 2px solid #eee; padding-bottom: 10px; }
                pre { background: #f6f8fa; padding: 16px; border-radius: 8px; }
                code { font-family: ui-monospace, monospace; }
                blockquote { border-left: 4px solid #dfe2e5; color: #6a737d; padding-left: 16px; margin-left: 0; }
                table { border-collapse: collapse; width: 100%; margin: 16px 0; }
                th, td { border: 1px solid #dfe2e5; padding: 8px 12px; }
                th { background-color: #f6f8fa; }
                #mermaid-root { width: 100%; display: flex; justify-content: center; }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <div id="mermaid-root"></div>
        </body>
        </html>
        """
        webView?.loadHTMLString(html, baseURL: nil)
    }

    private func loadLocalJS(named name: String) -> String {
        if let url = Bundle.main.url(forResource: name, withExtension: "js"),
           let content = try? String(contentsOf: url) {
            return content
        }
        return "// JS Library \(name) not found in Bundle"
    }
    
    /// 将 Markdown 导出为 PDF
    func exportToPDF(markdown: String, fileName: String) async throws -> URL {
        guard let webView = webView else { throw NSError(domain: "WebViewExport", code: 500) }
        
        let escapedMarkdown = markdown.replacingOccurrences(of: "\\", with: "\\\\")
                                      .replacingOccurrences(of: "`", with: "\\`")
                                      .replacingOccurrences(of: "$", with: "\\$")
        
        let js = """
        (async () => {
            document.getElementById('mermaid-root').innerHTML = '';
            const content = document.getElementById('content');
            content.innerHTML = marked.parse(`\(escapedMarkdown)`);
            await new Promise(r => setTimeout(r, 300));
            return true;
        })();
        """
        _ = try await webView.evaluateJavaScript(js)
        
        return try await createPDF(fileName: fileName)
    }

    /// 将 Mermaid 导出为 PDF
    func exportMindmapToPDF(mermaidCode: String, fileName: String) async throws -> URL {
        guard let webView = webView else { throw NSError(domain: "WebViewExport", code: 500) }
        
        let escapedCode = mermaidCode.replacingOccurrences(of: "\\", with: "\\\\")
                                     .replacingOccurrences(of: "`", with: "\\`")
                                     .replacingOccurrences(of: "$", with: "\\$")
        
        let js = """
        (async () => {
            document.getElementById('content').innerHTML = '';
            const root = document.getElementById('mermaid-root');
            mermaid.initialize({ startOnLoad: false, theme: 'neutral', securityLevel: 'loose', mindmap: { useMaxWidth: true } });
            const { svg } = await mermaid.render('mindmap-export', `\(escapedCode)`);
            root.innerHTML = svg;
            await new Promise(r => setTimeout(r, 500));
            return true;
        })();
        """
        _ = try await webView.evaluateJavaScript(js)
        
        return try await createPDF(fileName: fileName)
    }

    private func createPDF(fileName: String) async throws -> URL {
        guard let webView = webView else { throw NSError(domain: "WebViewExport", code: 500) }
        return try await withCheckedThrowingContinuation { continuation in
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                switch result {
                case .success(let data):
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
                    do {
                        try data.write(to: url)
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 将 Markdown 导出为 PPTX
    func exportToPPTX(markdown: String, fileName: String) async throws -> URL {
        guard let webView = webView else { throw NSError(domain: "WebViewExport", code: 500) }
        
        // 解析 Markdown 为幻灯片数据 (简单解析)
        let slides = parseMarkdownForSlides(markdown)
        let slidesJSON = try JSONEncoder().encode(slides)
        let slidesJSString = String(data: slidesJSON, encoding: .utf8) ?? "[]"
        
        let js = """
        (async () => {
            const pptx = new PptxGenJS();
            pptx.title = "\(fileName)";
            pptx.layout = 'LAYOUT_16x9';
            
            const slidesData = \(slidesJSString);
            
            slidesData.forEach(data => {
                let slide = pptx.addSlide();
                // 渐变背景或纯色
                slide.background = { fill: 'F5F7FA' };
                
                // 标题
                slide.addText(data.title, { 
                    x: 0.5, y: 0.5, w: '90%', h: 1, 
                    fontSize: 36, bold: true, color: '2D3436',
                    fontFace: 'Arial', align: 'center'
                });
                
                // 正文
                if (data.bullets && data.bullets.length > 0) {
                    slide.addText(data.bullets.map(b => ({ text: b, options: { bullet: true, indentLevel: 0, breakLine: true } })), { 
                        x: 1.0, y: 1.8, w: '80%', h: 3.5, 
                        fontSize: 20, color: '636E72', valign: 'top',
                        lineSpacing: 28
                    });
                }
                
                // 页码
                slide.addText('\(Localized.trf("export.generatedBy", Localized.tr("app.name")))', { x: 0.5, y: 5.0, fontSize: 10, color: 'B2BEC3' });
            });
            
            const base64 = await pptx.write('base64');
            return base64;
        })();
        """
        
        guard let base64String = try await webView.evaluateJavaScript(js) as? String,
              let data = Data(base64Encoded: base64String) else {
            throw NSError(domain: "PPTXExport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PPTX Base64"])
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pptx")
        try data.write(to: url)
        return url
    }
    
    // MARK: - Helper Methods
    
    private struct SlideData: Codable {
        let title: String
        let bullets: [String]
    }
    
    private func parseMarkdownForSlides(_ markdown: String) -> [SlideData] {
        var slides: [SlideData] = []
        let parts = markdown.components(separatedBy: "\n## ")
        for (index, part) in parts.enumerated() {
            let lines = part.components(separatedBy: .newlines)
            let title = lines.first?.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces) ?? Localized.trf("export.defaultSlideTitle", index + 1)
            let bullets = lines.dropFirst().filter { 
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") 
            }.map { 
                $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "* ", with: "") 
            }
            slides.append(SlideData(title: title, bullets: bullets))
        }
        return slides
    }
}

extension WebViewExportService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Export WebView failed to load: \(error)")
    }
}

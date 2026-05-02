@preconcurrency import SwiftUI
import WebKit

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
struct MermaidWebView: View {
    let mermaidCode: String
    @State private var webView: WKWebView?
    @State private var showExportSheet = false
    @State private var identifiablePDFURL: IdentifiableURL?

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            MermaidWKWebViewMac(mermaidCode: mermaidCode, webView: $webView)
                .frame(minHeight: 400)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            #else
            MermaidWKWebView(mermaidCode: mermaidCode, webView: $webView)
                .frame(minHeight: 400)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            #endif
        }
        .sheet(item: $identifiablePDFURL) { identifiable in
            ActivityView(activityItems: [identifiable.url])
        }
    }

    private func exportToPDF() {
        guard let webView = webView else { return }
        
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Mindmap.pdf")
                try? data.write(to: tempURL)
                self.identifiablePDFURL = IdentifiableURL(url: tempURL)
            case .failure(let error):
                print("PDF generation failed: \(error)")
            }
        }
    }
}

#if os(iOS)
struct MermaidWKWebView: UIViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.minimumZoomScale = 1.0
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(generateHTML(), baseURL: nil)
    }
    
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <style>
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; font-family: -apple-system; }
                .mermaid { background-color: transparent; width: 100%; padding: 20px; box-sizing: border-box; }
                svg { max-width: 100% !important; height: auto !important; }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(mermaidCode)
            </div>
            <script>
                mermaid.initialize({ 
                    startOnLoad: true, 
                    theme: 'neutral', 
                    securityLevel: 'loose',
                    mindmap: { useMaxWidth: true }
                });
            </script>
        </body>
        </html>
        """
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)
struct MermaidWKWebViewMac: NSViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(generateHTML(), baseURL: nil)
    }
    
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <style>
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; font-family: -apple-system; color: white; }
                .mermaid { background-color: transparent; width: 100%; padding: 20px; box-sizing: border-box; }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(mermaidCode)
            </div>
            <script>
                mermaid.initialize({ 
                    startOnLoad: true, 
                    theme: 'dark', 
                    securityLevel: 'loose',
                    mindmap: { useMaxWidth: true }
                });
            </script>
        </body>
        </html>
        """
    }
}
#endif

import SwiftUI
import WebKit

/// Mermaid 图表渲染视图 (高级可视化视角：所见即所得)
@MainActor
struct MermaidWebView: View {
    let mermaidCode: String
    
    var body: some View {
        #if os(macOS)
        MermaidWKWebViewMac(mermaidCode: mermaidCode)
            .frame(minHeight: 300)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        #else
        MermaidWKWebView(mermaidCode: mermaidCode)
            .frame(minHeight: 300)
            .background(Color.wikiCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        #endif
    }
}

#if os(iOS)
struct MermaidWKWebView: UIViewRepresentable {
    let mermaidCode: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
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
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <style>
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; font-family: -apple-system; }
                .mermaid { background-color: transparent; width: 100%; text-align: center; }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(mermaidCode)
            </div>
            <script>
                mermaid.initialize({ startOnLoad: true, theme: 'neutral', securityLevel: 'loose' });
            </script>
        </body>
        </html>
        """
    }
}
#elseif os(macOS)
struct MermaidWKWebViewMac: NSViewRepresentable {
    let mermaidCode: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
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
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; font-family: -apple-system; color: white; }
                .mermaid { background-color: transparent; width: 100%; text-align: center; }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(mermaidCode)
            </div>
            <script>
                mermaid.initialize({ startOnLoad: true, theme: 'dark', securityLevel: 'loose' });
            </script>
        </body>
        </html>
        """
    }
}
#endif

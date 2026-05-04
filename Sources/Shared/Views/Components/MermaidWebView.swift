// MermaidWebView.swift
//
// 作者: Wang Chong
// 功能说明: struct IdentifiableURL
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
//   - 更新: 2026-05-03
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

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
        ZStack(alignment: .bottomTrailing) {
            #if os(macOS)
            MermaidWKWebViewMac(mermaidCode: mermaidCode, webView: $webView)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            #else
            MermaidWKWebView(mermaidCode: mermaidCode, webView: $webView)
                .background(Color.wikiCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            #endif
            
            // Zoom Controls
            HStack(spacing: 12) {
                zoomButton(icon: "minus.magnifyingglass") { zoom(by: 0.8) }
                zoomButton(icon: "arrow.counterclockwise") { resetZoom() }
                zoomButton(icon: "plus.magnifyingglass") { zoom(by: 1.2) }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4)
            .padding(16)
        }
        .frame(minHeight: 400)
        .sheet(item: $identifiablePDFURL) { identifiable in
            ActivityView(activityItems: [identifiable.url])
        }
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.wikiText)
                .frame(width: 32, height: 32)
                .background(Color.wikiCard.opacity(0.5))
                .clipShape(Circle())
        }
    }

    private func zoom(by factor: CGFloat) {
        #if os(iOS)
        guard let webView = webView else { return }
        let currentScale = webView.scrollView.zoomScale
        let newScale = min(max(currentScale * factor, webView.scrollView.minimumZoomScale), webView.scrollView.maximumZoomScale)
        webView.scrollView.setZoomScale(newScale, animated: true)
        #endif
    }

    private func resetZoom() {
        #if os(iOS)
        webView?.scrollView.setZoomScale(1.0, animated: true)
        #endif
    }

    private func exportToPDF() {
        guard let webView = webView else { return }
        
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(Localized.tr("synthesis.mindmap.title")).pdf")
                try? data.write(to: tempURL)
                self.identifiablePDFURL = IdentifiableURL(url: tempURL)
            case .failure(let error):
                ToastManager.shared.show(type: .error, message: error.localizedDescription)
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
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; width: 100vw; font-family: -apple-system; }
                .mermaid { background-color: transparent; width: 100%; height: 100%; padding: 20px; box-sizing: border-box; }
                svg { max-width: 100% !important; height: auto !important; }
            </style>
        </head>
        <body>
            <div id="mermaid-root"></div>
            <script>
                mermaid.initialize({
                    startOnLoad: false,
                    theme: 'neutral',
                    securityLevel: 'loose',
                    mindmap: { useMaxWidth: true }
                });
                (async () => {
                    try {
                        const { svg } = await mermaid.render('mindmap-svg', `\(mermaidCode.replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$"))`);
                        document.getElementById('mermaid-root').innerHTML = svg;
                    } catch (e) {
                        document.getElementById('mermaid-root').innerHTML = '<div style="color:#999;text-align:center;padding:40px 20px;font-size:14px">\(Localized.tr("synthesis.mindmap.renderError"))</div>';
                    }
                })();
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

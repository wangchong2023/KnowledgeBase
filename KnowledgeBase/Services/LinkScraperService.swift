import Foundation

/// 链接解析服务：负责从网页或 YouTube 提取 Markdown 内容
final class LinkScraperService {
    
    enum ScraperError: Error {
        case invalidURL
        case networkError(Error)
        case parsingFailed
    }
    
    /// 抓取网页内容并转换为 Markdown (使用 Jina Reader API 作为中转，适合 LLM)
    func fetchMarkdown(from urlString: String) async throws -> (markdown: String, title: String) {
        guard let url = URL(string: urlString) else {
            throw ScraperError.invalidURL
        }
        
        // 使用 r.jina.ai 这是一个非常棒的工具，可以将任何网页转为干净的 Markdown
        let jinaURLString = "https://r.jina.ai/\(url.absoluteString)"
        guard let jinaURL = URL(string: jinaURLString) else {
            throw ScraperError.invalidURL
        }
        
        var request = URLRequest(url: jinaURL)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ScraperError.parsingFailed
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw ScraperError.parsingFailed
        }
        
        // 尝试从 Markdown 中提取标题（通常第一行是 # Title）
        let lines = content.components(separatedBy: .newlines)
        let title = lines.first(where: { $0.hasPrefix("# ") })?.replacingOccurrences(of: "# ", with: "") 
                    ?? url.host ?? "未命名网页"
        
        return (content, title)
    }
}

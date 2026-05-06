// WebScraperProcessor.swift
//
// 作者: Wang Chong
// 功能说明: 本文件实现了知识管理系统的网络内容抓取处理器（WebScraperProcessor），负责将外部 URL 资源转化为系统可识别的 Markdown 格式。
// 该处理器主要通过集成第三方解析引擎（如 Jina Reader）实现以下核心功能：
// 1. 跨平台网页抓取：支持将任意网页 URL 转换为干净、去除噪声的 Markdown 文本，极大地方便了 LLM 的后续处理。
// 2. 自动标题提取：通过解析抓取后的内容流自动识别网页主标题，为知识页面的初始化提供元数据支持。
// 3. 网络异常处理：内置了超时机制与状态码校验，确保在复杂网络环境下资料采集任务的稳定性。
// 版本: 1.2
// 修改记录:
//   - 2026-05-05: 由 LinkProcessor 更名为 WebScraperProcessor，移入 Network 目录，并同步升级文档规范
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 网页内容提取处理器：负责从 URL 提取 Markdown 内容
final class WebScraperProcessor: @unchecked Sendable {
    
    enum ScraperError: Error {
        case invalidURL
        case networkError(Error)
        case parsingFailed
    }
    
    /// 抓取网页内容并转换为 Markdown (使用 Jina Reader API 作为中转，适合 LLM)
    func fetchMarkdown(from urlString: String) async throws -> (markdown: String, title: String) {
        let startTime = Date()
        var normalizedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedString.lowercased().hasPrefix("http://") && !normalizedString.lowercased().hasPrefix("https://") {
            normalizedString = "https://" + normalizedString
        }
        
        guard let url = URL(string: normalizedString) else {
            throw ScraperError.invalidURL
        }
        
        // 使用 r.jina.ai 这是一个非常棒的工具，可以将任何网页转为干净的 Markdown
        let jinaURLString = "\(AppConfig.jinaReaderURL)\(url.absoluteString)"
        guard let jinaURL = URL(string: jinaURLString) else {
            throw ScraperError.invalidURL
        }
        
        var request = URLRequest(url: jinaURL)
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScraperError.parsingFailed
            }
            
            if httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "No body"
                print("Scraper HTTP Error \(httpResponse.statusCode): \(body)")
                throw ScraperError.networkError(NSError(domain: "WebScraper", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]))
            }
            
            guard let content = String(data: data, encoding: .utf8) else {
                throw ScraperError.parsingFailed
            }
            
            // 尝试从 Markdown 中提取标题（通常第一行是 # Title）
            let lines = content.components(separatedBy: .newlines)
            let title = lines.first(where: { $0.hasPrefix("# ") })?.replacingOccurrences(of: "# ", with: "") 
                        ?? url.host ?? "未命名网页"
            
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.addLog(
                action: .ingest,
                target: url.host ?? urlString,
                details: "Successfully scraped webpage. Length: \(content.count)",
                duration: duration,
                startTime: startTime,
                endTime: Date(),
                module: "WebScraper"
            )
            
            return (content, title)
        } catch let error as ScraperError {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.addLog(
                action: .error,
                target: urlString,
                details: "Scraper Error: \(error)",
                duration: duration,
                startTime: startTime,
                endTime: Date(),
                module: "WebScraper"
            )
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.addLog(
                action: .error,
                target: urlString,
                details: "Network Error: \(error.localizedDescription)",
                duration: duration,
                startTime: startTime,
                endTime: Date(),
                module: "WebScraper"
            )
            throw ScraperError.networkError(error)
        }
    }
}

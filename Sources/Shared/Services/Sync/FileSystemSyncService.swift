// FileSystemSyncService.swift
//
// 作者: Wang Chong
// 功能说明: 文件系统同步服务：将数据库内容导出为物理 Markdown 文件
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation

/// 文件系统同步服务：将数据库内容导出为物理 Markdown 文件
final class FileSystemSyncService {
    
    /// 导出整个知识库到指定目录，按 PageType 分类存放
    func exportToMarkdown(pages: [WikiPage], destinationURL: URL) throws {
        let fm = FileManager.default
        
        // 确保主目录存在
        if !fm.fileExists(atPath: destinationURL.path) {
            try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }
        
        for page in pages {
            // 确定子目录 (如 wiki/entities/)
            let subfolder = page.folderName
            let folderURL = destinationURL.appendingPathComponent(subfolder)
            
            if !fm.fileExists(atPath: folderURL.path) {
                try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            // 构建文件名 (处理非法字符)
            let safeTitle = page.title.replacingOccurrences(of: "/", with: "-")
                                      .replacingOccurrences(of: ":", with: "-")
            let fileURL = folderURL.appendingPathComponent("\(safeTitle).md")
            
            // 构建 Markdown 内容 (包含元数据 YAML)
            let yaml = """
            ---
            title: \(page.title)
            type: \(page.type.rawValue)
            tags: \(page.tags.joined(separator: ", "))
            updated: \(page.updated.formatted())
            ---
            
            """
            let fullContent = yaml + page.content
            
            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

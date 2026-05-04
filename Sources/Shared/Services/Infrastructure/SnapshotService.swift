// SnapshotService.swift
//
// 作者: Wang Chong
// 功能说明: 知识版本快照服务 (Snapshot Service)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation

/// 知识版本快照服务 (Snapshot Service)
/// 用于在页面发生重大变更（如智能折叠、重构）前后记录物理快照，提供“后悔药”机制。
final class SnapshotService {
    private let fileManager = FileManager.default
    private let snapshotsURL: URL

    init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.snapshotsURL = docs.appendingPathComponent(".snapshots", isDirectory: true)
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: snapshotsURL.path) {
            try? fileManager.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)
        }
    }

    /// 为指定页面保存快照
    func saveSnapshot(for page: WikiPage) {
        let pageDir = snapshotsURL.appendingPathComponent(page.id.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: pageDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileURL = pageDir.appendingPathComponent("\(timestamp).md")
        
        // 构建带元数据的快照内容
        let snapshotContent = """
        ---
        Snapshot-Date: \(timestamp)
        Original-Title: \(page.title)
        ---
        
        \(page.content)
        """
        
        try? snapshotContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 获取某个页面的所有历史快照
    func getHistory(for pageID: UUID) -> [SnapshotInfo] {
        let pageDir = snapshotsURL.appendingPathComponent(pageID.uuidString, isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(at: pageDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> SnapshotInfo? in
                let timestamp = url.deletingPathExtension().lastPathComponent
                guard let date = ISO8601DateFormatter().date(from: timestamp) else { return nil }
                return SnapshotInfo(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    /// 从快照回滚
    func rollback(to snapshot: SnapshotInfo) -> String? {
        guard let content = try? String(contentsOf: snapshot.url, encoding: .utf8) else { return nil }
        
        // 剥离 Frontmatter
        let parts = content.components(separatedBy: "---")
        if parts.count >= 3 {
            return parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content
    }
}

struct SnapshotInfo: Identifiable {
    var id: String { url.path }
    let url: URL
    let date: Date
}

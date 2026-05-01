import Foundation

struct ExternalPage {
    let url: URL
    let title: String
    let content: String
    let lastModified: Date
}

class VaultService {
    static let shared = VaultService()
    
    /// 扫描指定文件夹下的所有 Markdown 文件
    func scan(directory: URL) -> [ExternalPage] {
        var results: [ExternalPage] = []
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "md" {
                if let page = processFile(at: fileURL) {
                    results.append(page)
                }
            }
        }
        
        return results
    }
    
    private func processFile(at url: URL) -> ExternalPage? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // 提取标题（优先找 H1，否则用文件名）
            let title = extractTitle(from: content) ?? url.deletingPathExtension().lastPathComponent
            
            return ExternalPage(
                url: url,
                title: title,
                content: content,
                lastModified: modificationDate
            )
        } catch {
            print("Failed to process external file \(url): \(error)")
            return nil
        }
    }
    
    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return trimmed.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
    
    /// 存储书签以备持久化访问 (iOS/macOS)
    func storeBookmark(for url: URL) {
        do {
            let data = try url.bookmarksData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: "vault_bookmark_\(url.lastPathComponent)")
        } catch {
            print("Failed to create bookmark: \(error)")
        }
    }
    
    /// 从书签恢复 URL 访问权限
    func restoreURL(from data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                // 如果书签过期，这里可以处理（例如请求重新授权）
                return nil
            }
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }
}

// SpotlightService.swift
//
// 作者: Wang Chong
// 功能说明: Spotlight 索引服务 (Expert Design Item #3)
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: 版权所有 © 2026 Wang Chong。保留所有权利。

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Spotlight 索引服务 (Expert Design Item #3)
/// 将 Wiki 页面索引至 iOS/macOS 系统搜索。
@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    
    private init() {}
    
    /// 索引单张页面
    func indexPage(_ page: WikiPage) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .plainText)
        attributeSet.title = page.title
        attributeSet.contentDescription = String(page.content.prefix(100))
        attributeSet.keywords = Array(page.tags)
        
        let item = CSSearchableItem(
            uniqueIdentifier: page.id.uuidString,
            domainIdentifier: "com.zhimind.pages",
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                Logger.shared.error("🔍 [Spotlight] 索引失败：\(error.localizedDescription)")
            }
        }
    }
    
    /// 移除页面索引
    func removeIndex(for pageID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [pageID.uuidString]) { _ in }
    }
    
    /// 全量重新索引 (建议在应用启动或数据库重置时调用)
    func reindexAll(pages: [WikiPage]) {
        CSSearchableIndex.default().deleteAllSearchableItems { [weak self] _ in
            Task { @MainActor in
                pages.forEach { self?.indexPage($0) }
            }
        }
    }
}

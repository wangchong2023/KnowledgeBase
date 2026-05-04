// DeepLinkService.swift
//
// 作者: Wang Chong
// 功能说明: Handles deep links, universal links, and Spotlight indexing for Knowledge Base pages.
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-02
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import Foundation
import CoreSpotlight

// MARK: - Deep Link Service
/// Handles deep links, universal links, and Spotlight indexing for Knowledge Base pages.
final class DeepLinkService: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    
    enum DeepLink {
        case openPage(id: UUID)
        case openPageByTitle(String)
        case search(String)
        case ingest
        case graph
        case chat
    }
    
    // MARK: - URL Scheme Handling
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "km" else { return false }
        
        switch url.host {
        case "page":
            if let idString = url.queryParameters["id"],
               let id = UUID(uuidString: idString) {
                pendingDeepLink = .openPage(id: id)
                return true
            }
            if let title = url.queryParameters["title"] {
                pendingDeepLink = .openPageByTitle(title)
                return true
            }
            
        case "search":
            if let query = url.queryParameters["q"] {
                pendingDeepLink = .search(query)
                return true
            }
            
        case "ingest":
            pendingDeepLink = .ingest
            return true
            
        case "graph":
            pendingDeepLink = .graph
            return true
            
        case "chat":
            pendingDeepLink = .chat
            return true
            
        default:
            break
        }
        
        return false
    }
    
    // MARK: - Spotlight Indexing
    func indexPages(_ pages: [WikiPage]) {
        var searchableItems: [CSSearchableItem] = []
        
        for page in pages {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = page.title
            attributeSet.contentDescription = String(page.content.prefix(200))
            attributeSet.keywords = page.tags + page.aliases
            
            let activity = NSUserActivity(activityType: "com.km.app.openPage")
            activity.userInfo = ["pageID": page.id.uuidString]
            activity.title = page.title
            attributeSet.relatedUniqueIdentifier = page.id.uuidString
            
            let item = CSSearchableItem(
                uniqueIdentifier: page.id.uuidString,
                domainIdentifier: "com.km.app.pages",
                attributeSet: attributeSet
            )
            item.expirationDate = nil
            searchableItems.append(item)
        }
        
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print(String(format: L10n.Common.tr("deepLink.log.indexingFailed"), error.localizedDescription))
            }
        }
    }
    
    func deindexPage(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [id.uuidString]
        ) { _ in }
    }
    
    func deindexAllPages() {
        CSSearchableIndex.default().deleteAllSearchableItems() { _ in }
    }
    
    // MARK: - Spotlight Query Handling
    func handleSpotlightActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == "com.km.app.openPage",
              let userInfo = userActivity.userInfo,
              let idString = userInfo["pageID"] as? String,
              let id = UUID(uuidString: idString) else {
            return false
        }
        pendingDeepLink = .openPage(id: id)
        return true
    }
    
    func consumeDeepLink() -> DeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }
}

// MARK: - URL Query Parameters Extension
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return [:] }
        return Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}

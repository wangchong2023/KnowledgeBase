// PageDetailViewModel.swift
//
// 作者: Wang Chong
// 功能说明: Page Detail视图模型.swift
// 版本: 1.0
// 修改记录:
//   - 创建: 2026-05-04
// 日期: 2026-05-04
// 版权: Copyright © 2026 Wang Chong. All rights reserved.

import SwiftUI
import Observation

@MainActor
@Observable
final class PageDetailViewModel {
    var page: WikiPage
    var isEditing = false
    var showBacklinks = false
    var showDeleteConfirmation = false
    var showAliasEditor = false
    var newAlias = ""
    var showIconPicker = false
    var showSnapshotHistory = false

    @ObservationIgnored @Inject private var store: KMStore

    init(page: WikiPage) {
        self.page = page
    }

    var backlinks: [WikiPage] {
        store.pages.filter { page in
            page.content.contains("[[\(self.page.title)]]") || page.content.contains("[[\(self.page.title)|")
        }
    }

    func deletePage() {
        store.deletePage(page)
    }

    func addAlias() {
        let trimmed = newAlias.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !page.aliases.contains(trimmed) else { return }
        var updated = page
        updated.aliases.append(trimmed)
        store.savePage(updated)
        page = updated
    }

    func removeAlias(_ alias: String) {
        var updated = page
        updated.aliases.removeAll { $0 == alias }
        store.savePage(updated)
        page = updated
    }

    func togglePin() {
        var updated = page
        updated.isPinned.toggle()
        store.savePage(updated)
        page = updated
    }

    func updateType(_ type: PageType) {
        var updated = page
        updated.type = type
        store.savePage(updated)
        page = updated
    }

    func updateStatus(_ status: PageStatus) {
        var updated = page
        updated.status = status
        store.savePage(updated)
        page = updated
    }

    func updateConfidence(_ confidence: Confidence) {
        var updated = page
        updated.confidence = confidence
        store.savePage(updated)
        page = updated
    }
}
